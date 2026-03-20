# Tasks: Activity Log, What, and Recap

**Input**: `specs/001-activity-log/`
**Repos touched**: get-clear, reminders-cli, calendar-cli, contacts-cli, mail-cli, sms-cli

---

## Phase 1: GetClearKit Foundation

**Purpose**: Core log infrastructure in the shared package. Everything else depends on this phase. Build order from quickstart.md: GetClearKit first, then tool changes, then get-clear binary.

**Repo**: `~/dev/get-clear/`

- [ ] T001 Create `Sources/GetClearKit/ActivityLog.swift` — POSIX O_APPEND writer; `ActivityLog.write(tool:cmd:desc:container:)`; creates `~/.local/share/get-clear/log/` on first use; silent on failure (never propagates errors)
- [ ] T002 Create `Sources/GetClearKit/ActivityLogReader.swift` — JSONL parser; `ActivityLogReader.entries(for:tool:)` with date range filter; skips malformed lines silently; implements FR-018 recency rule (3-hour window)
- [ ] T003 Create `Sources/GetClearKit/TimespanFormatter.swift` — rounds timestamps to nearest 15 minutes; formats range string "9:00am → 4:45pm"; handles single-entry and no-entry cases (FR-009d)
- [ ] T004 Create `Tests/GetClearKitTests/ActivityLogTests.swift` — covers:
  - Write produces valid JSONL line with all fields
  - Reader parses and filters by tool, date range, command
  - Reader skips malformed/unknown lines without crashing
  - TimespanFormatter rounds correctly (boundary: X:07 → X:00, X:08 → X:15)
  - FR-018: recency rule triggers within 3 hours, does not trigger beyond
  - Empty range returns correct empty result

**Checkpoint**: `swift run getclearkit-tests` passes. GetClearKit is ready for tool integration.

---

## Phase 2: Tool Lib Changes — Log Write Calls

**Purpose**: Every successful write command in all five tools logs an entry (FR-001). These are independent of each other and can be done in parallel once Phase 1 is complete.

**Pattern**: After each successful write command in `*Lib`, add:
```swift
try? ActivityLog.write(tool: "<tool>", cmd: "<cmd>", desc: <title/name/recipient>, container: <list/calendar/nil>)
```

- [ ] T005 [P] **reminders-cli** — `Sources/RemindersLib/`: add `ActivityLog.write()` after `add`, `remove`, `change`, `rename`, `done`. Container = list name (always). Repo: `~/dev/reminders-cli/`
- [ ] T006 [P] **calendar-cli** — `Sources/CalendarLib/`: add `ActivityLog.write()` after `add`, `remove`. Container = calendar name (always). Repo: `~/dev/calendar-cli/`
- [ ] T007 [P] **contacts-cli** — `Sources/ContactsLib/`: add `ActivityLog.write()` after `add`, `remove`, `change`, `rename`. Container = group name for `add to` / `remove from` ops; nil for contact-level ops. Repo: `~/dev/contacts-cli/`
- [ ] T008 [P] **mail-cli** — `Sources/MailLib/`: add `ActivityLog.write()` after `send`. Container = nil. Repo: `~/dev/mail-cli/`
- [ ] T009 [P] **sms-cli** — `Sources/SMSLib/`: add `ActivityLog.write()` after `send`. Container = nil. Repo: `~/dev/sms-cli/`

**Checkpoint** (US4 — Log Survives Across Sessions): In two separate terminal sessions, perform one write action each. Run `cat ~/.local/share/get-clear/log/$(date +%Y-%m-%d).log` in a third session and confirm both entries are present.

---

## Phase 3: Per-Tool `what` Command (US2 — P2)

**Purpose**: Each tool gets `<tool> what [range]` dispatching to `ActivityLogReader`. Independent per tool; can proceed in parallel.

**Output contract**: See `contracts/cli-commands.md` — chronological list, timestamp · cmd · desc · [container]. Date header for any non-today range. Empty state: "Nothing recorded in <tool> today." / "Nothing recorded in <tool> yesterday."

- [ ] T010 [P] **reminders-cli** — `Sources/RemindersCLI/main.swift`: add `what [range]` dispatch; call `ActivityLogReader.entries(for: range, tool: "reminders")`; format and print per contract. Repo: `~/dev/reminders-cli/`
- [ ] T011 [P] **calendar-cli** — same pattern, tool: "calendar". Repo: `~/dev/calendar-cli/`
- [ ] T012 [P] **contacts-cli** — same pattern, tool: "contacts". Repo: `~/dev/contacts-cli/`
- [ ] T013 [P] **mail-cli** — same pattern, tool: "mail". Repo: `~/dev/mail-cli/`
- [ ] T014 [P] **sms-cli** — same pattern, tool: "sms". Repo: `~/dev/sms-cli/`

**Independent test per tool**: Add a reminder, run `reminders what` — confirm the action appears with timestamp and no other tools' entries. Run `reminders what yesterday` — confirm date header appears.

---

## Phase 4: get-clear Binary — `what` (US1 — P1)

**Purpose**: Suite-level `get-clear what [range]` aggregating all five tools. New executable target in the umbrella repo.

**Repo**: `~/dev/get-clear/`

- [ ] T015 Add `GetClear` executable target to `Package.swift`:
  ```swift
  .executableTarget(name: "get-clear", dependencies: ["GetClearKit"], path: "Sources/GetClear")
  ```
- [ ] T016 Create `Sources/GetClear/main.swift` — dispatch `what [range]` and `recap [range]` (recap stubbed for now)
- [ ] T017 Implement `get-clear what [range]` — call `ActivityLogReader.entries(for: range, tool: nil)` (all tools); format per contract: timestamp · tool · cmd · desc · [container]; date header rule; multi-day gap handling (skip empty days, "X of Y days recorded" footer); FR-018 recency rule

**Independent test** (US1): Use all five tools for at least one write action each. Run `get-clear what` — confirm all actions appear in chronological order with tool column.

---

## Phase 5: get-clear Binary — `recap` (US3 — P3)

**Purpose**: Commitments-kept summary from live data sources. Requires EventKit entitlement.

**Repo**: `~/dev/get-clear/`

- [ ] T018 Add EventKit entitlement: create `Sources/GetClear/get-clear.entitlements` with `com.apple.security.personal-information.calendars` and `com.apple.security.personal-information.reminders`
- [ ] T019 Create `Sources/GetClearKit/RecapAggregator.swift` — coordinates three live queries:
  - **Reminders**: `EKEventStore.predicateForReminders(in:)` + filter by `completionDate` in range (FR-009a)
  - **Calendar**: `EKEventStore.predicateForEvents(withStart:end:)` + post-filter per FR-015 (end-time for timed events, date comparison for all-day)
  - **Mail + SMS sent**: `ActivityLogReader` filtered to `cmd: "send"` from `mail` and `sms`
  - Returns `RecapResult` with groups and timespan
- [ ] T020 Implement `get-clear recap [range]` output in `Sources/GetClear/main.swift`:
  - Timespan header: "Wednesday March 19 · 9:00am → 4:45pm" (FR-009d, rounded to 15 min)
  - Groups in order: "From your calendar", "Tasks completed", "Sent"
  - Omit empty groups
  - Empty state today: "Quiet so far. Ready for the next thing." (FR-010)
  - Empty state past: "Nothing recorded yesterday."
  - Multi-day ranges: skip empty days; no footer (recap omits coverage metadata)
  - FR-018: recency rule applies to today empty state

**Independent test** (US3): Complete a reminder from the phone, send an email, have a past calendar event. Run `get-clear recap` — confirm all three appear grouped by type. Run `get-clear recap yesterday` — confirm date header appears.

---

## Phase 6: Polish

- [ ] T021 [P] Update `get-clear` README / install docs to document `what` and `recap` commands
- [ ] T022 [P] Verify `get-clear what` returns in under 1 second for a full week range (SC-002)
- [ ] T023 Manual end-to-end: FR-018 midnight edge case — set system time to 12:05am with a full prior day's log, confirm `get-clear what` and `get-clear recap` show previous day's data with date header

---

## Dependencies & Execution Order

```
Phase 1 (GetClearKit)
  └── Phase 2 (Tool Lib writes) — parallel across 5 tools
        └── Phase 3 (per-tool what) — parallel across 5 tools
  └── Phase 4 (get-clear what)
        └── Phase 5 (get-clear recap)
              └── Phase 6 (Polish)
```

Phase 2 and Phase 4 both depend only on Phase 1. Phase 3 tasks are independent per tool. Phase 5 requires Phase 4 (binary already exists with `what` working).

---

## Notes

- `try? ActivityLog.write(...)` everywhere — log failure MUST NOT fail the command (quickstart critical constraint)
- System clock only — never accept a timestamp from an argument or environment (FR-016)
- POSIX `O_APPEND` — do not use `FileHandle.seekToEndOfFile()` (research.md)
- All-day events: `startDate` date comparison, not `endDate <= now` (FR-015)
- Contacts do not appear in `recap` — by design (see spec.md Design Notes)
