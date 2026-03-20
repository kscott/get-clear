# Research: Activity Log, What, and Recap

## Log File Format

**Decision**: JSON Lines (JSONL) — one JSON object per line, newline-terminated.

**Rationale**: Each line is a complete, independently parseable record. Safe to append without reading the file first. Machine-readable for GetClearKit, human-scannable in a text editor, compatible with standard Unix tools (`jq`, `grep`). Codable conformance in Swift provides validation for free.

**Format**:
```json
{"ts":"2026-03-19T21:32:00Z","tool":"reminders","cmd":"done","desc":"Call Sarah","container":"Ibotta"}
{"ts":"2026-03-19T21:45:00Z","tool":"mail","cmd":"send","desc":"Alex Re: proposal","container":null}
```

Fields: `ts` (ISO 8601), `tool`, `cmd`, `desc` (human-readable description of the record), `container` (list/calendar name, nullable).

**Multi-day query performance**: Range queries open one file per day in the range (e.g., `what this week` = 7 files, ~21KB total). At personal-tool scale this is well under 1 second. Per-day files were chosen over a single rolling file or monthly files because log rotation (issue #18) is trivial — delete files older than N days.

**Revisit if**: Query latency becomes noticeable for ranges > 90 days, or file count at open/read becomes measurable. When telemetry (issue #14) is built, `what`/`recap` query duration and files-opened count are the right metrics to track. If either trends upward, reconsider monthly files or a lightweight index.

**Alternatives considered**: TSV — simpler but harder to extend without breaking parsers. Plain text — requires regex, no structure. SQLite — fast indexed queries but binary, not human-readable, overkill for this scale. Monthly files — fewer file opens for range queries but coarser rotation granularity.

---

## Concurrent File Appending

**Decision**: POSIX `open(O_WRONLY | O_APPEND | O_CREAT)` + `write()` + `close()` via Darwin import in GetClearKit.

**Rationale**: The macOS kernel guarantees that `O_APPEND` writes are atomic for small payloads (≤256 bytes, well within a single log entry). No file locking needed. Swift's `FileHandle` does not expose `O_APPEND` — must use POSIX directly.

**Pattern** (for `ActivityLog.swift` in GetClearKit):
```swift
import Darwin
let fd = open(path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
defer { close(fd) }
data.withCString { Darwin.write(fd, $0, strlen($0)) }
```

**Alternatives considered**: `FileHandle.seekToEndOfFile()` + `write()` — not safe for concurrent processes; seek and write are separate operations. `NSFileCoordinator` — designed for iCloud coordination, unnecessary overhead for local files.

---

## EventKit Completed Reminders Query

**Decision**: `EKEventStore.predicateForReminders(in:)` with post-filter on `completionDate`.

**Rationale**: Querying the Reminders database directly captures completions from any source — the app, Siri, the CLI, a watch — not just those recorded in the activity log. This is more honest: recap's question is "where did you keep your commitments?" and the answer shouldn't depend on which interface you used. No duplicate checks or log/database reconciliation needed.

**Pattern** (for `recap` in the get-clear binary):
```swift
let predicate = store.predicateForReminders(in: nil)  // nil = all calendars
store.fetchReminders(matching: predicate) { reminders in
    let completed = (reminders ?? []).filter { reminder in
        guard reminder.isCompleted, let completionDate = reminder.completionDate else { return false }
        return completionDate >= rangeStart && completionDate <= rangeEnd
    }
}
```

**Retention note**: Reminders preserves completed items and their `completionDate` indefinitely unless the user manually deletes them. Surface this honestly if querying a very old range returns nothing unexpected.

**Alternatives considered**: Using the activity log for reminders completions — rejected because it misses completions from any interface other than the CLI. Requires no deduplication and avoids timestamp format differences between log entries and EventKit dates.

---

## EventKit Past-Event Query

**Decision**: `EKEventStore.predicateForEvents(withStart:end:calendars:)` with `end = Date()`, then post-filter.

**Pattern** (for `recap` in the get-clear binary):
```swift
let predicate = store.predicateForEvents(withStart: rangeStart, end: Date(), calendars: nil)
let events = store.events(matching: predicate).filter { event in
    if event.isAllDay {
        // FR-015: date comparison for all-day events
        return Calendar.current.isDate(event.startDate, inSameDayAs: queryDate)
            || event.startDate < queryDate
    } else {
        return event.endDate <= Date()
    }
}
```

**All-day event nuance**: EventKit sets all-day event `endDate` to midnight of the following day. A strict `endDate <= now` check at 3pm would correctly exclude today's all-day events (midnight tomorrow hasn't passed). FR-015 requires date comparison instead — an all-day event is "occurred" if its calendar date is within the query range. This requires checking `startDate` date component, not `endDate`.

**Alternatives considered**: Iterating calendars manually — slower, no predicate optimization. Caching events — unnecessary complexity for a personal tool with small event counts.

---

## get-clear Binary Architecture

**Decision**: New `GetClear` Swift executable target in the umbrella repo's `Package.swift`. Depends on GetClearKit. Has EventKit entitlement for `recap`.

**Rationale**: The suite-level `what` and `recap` commands need cross-tool log aggregation (all tools' log files) and EventKit access (for past calendar events in recap). A shell script would bypass GetClearKit and Swift type safety. A separate tool repo would be disproportionate for two commands.

**Package.swift addition**:
```swift
.executableTarget(
    name: "get-clear",
    dependencies: ["GetClearKit"],
    path: "Sources/GetClear"
)
```

Entitlement file (`Sources/GetClear/get-clear.entitlements`) needs `com.apple.security.personal-information.calendars`.

---

## ~~FR-017 Add/Remove Suppression~~ *(removed)*

Not needed. Recap queries the Reminders database and EventKit directly — cancelled reminders aren't completed, removed calendar events aren't present. The data stores enforce correctness naturally. `RecapAggregator` requires no suppression logic.
