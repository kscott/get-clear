# Data Model: Activity Log, What, and Recap

## ActivityLogEntry

The atomic unit written to the log file and read back by `what` and `recap`.

| Field | Type | Required | Description |
|---|---|---|---|
| `ts` | ISO 8601 string | Yes | Timestamp from system clock at moment of execution (FR-016) |
| `tool` | string | Yes | One of: `reminders`, `calendar`, `contacts`, `mail`, `sms` |
| `cmd` | string | Yes | The command executed: `add`, `remove`, `change`, `rename`, `done`, `send` |
| `desc` | string | Yes | Human-readable description of the record acted on — the title, name, or recipient |
| `container` | string or null | No | The scoping container for the action. Reminders: always the list name. Calendar: always the calendar name. Contacts: group name when the action is group membership (`add to` / `remove from`), null for contact-level operations (`add`, `change`, `rename`, `remove`). Mail, SMS: always null. |

**Serialized form** (JSON Lines — one object per line):
```json
{"ts":"2026-03-19T21:32:00Z","tool":"reminders","cmd":"done","desc":"Call Sarah","container":"Ibotta"}
{"ts":"2026-03-19T21:45:00Z","tool":"mail","cmd":"send","desc":"Alex Re: proposal","container":null}
{"ts":"2026-03-19T22:10:00Z","tool":"calendar","cmd":"add","desc":"Sprint review","container":"Work"}
{"ts":"2026-03-19T22:15:00Z","tool":"contacts","cmd":"add","desc":"Bob Smith","container":null}
{"ts":"2026-03-19T22:16:00Z","tool":"contacts","cmd":"add","desc":"Bob Smith → Team Members","container":"Team Members"}
```

**Validation rules**:
- `ts` must be a valid ISO 8601 datetime; entries with unparseable timestamps are skipped by the reader
- `tool` must be one of the five known values; unknown tools are skipped
- `cmd` must be a known write command; unknown commands are skipped
- `desc` must be non-empty; empty-desc entries are skipped
- Malformed lines (invalid JSON, missing required fields) are silently skipped — the log is best-effort

---

## Daily Log File

One file per calendar day, all five tools write to the same directory.

**Location**: `~/.local/share/get-clear/log/YYYY-MM-DD.log`
**Format**: JSON Lines — one `ActivityLogEntry` per line, newline-terminated
**Write mode**: POSIX `O_APPEND` — each entry is appended atomically
**Encoding**: UTF-8

The date in the filename is the local calendar date at time of write (from the system clock). A log entry written at 11:58pm and another at 12:02am go into different files.

---

## Recap View

Not a stored entity — derived at query time from two sources:

**From the Reminders database** (live query at report time):
- `EKReminder` where `isCompleted == true` and `completionDate` falls within the query range → Tasks completed

**From the log** (filtered by command type):
- `cmd: "send"` from tools `mail` or `sms` → Sent

**From EventKit** (live query at report time):
- Past calendar events within the query range (per FR-015 date rules) → From your calendar

**Suppression**: Not needed. Recap queries live data stores for reminders and calendar — cancelled items simply aren't present. Mail and SMS are log-sourced but have no remove equivalent.

**Output groups**:
| Group label | Source | Commands |
|---|---|---|
| From your calendar | EventKit (live query) | Past events in range |
| Tasks completed | Reminders database (live query) | `EKReminder.completionDate` in range |
| Sent | Log | `mail send`, `sms send` |

**Timespan** (FR-009d): First and last `ts` in the log entries for the range, rounded to nearest 15 minutes. Derived from log entries only (not EventKit events). Null if no log entries exist for the range.

---

## Swift Types (GetClearKit)

```swift
// ActivityLogEntry.swift
public struct ActivityLogEntry: Codable {
    public let ts: Date
    public let tool: String
    public let cmd: String
    public let desc: String
    public let container: String?
}

// RecapEntry.swift
public enum RecapGroup {
    case fromCalendar([EKEvent])
    case tasksCompleted([ActivityLogEntry])
    case sent([ActivityLogEntry])
}

public struct RecapResult {
    public let groups: [RecapGroup]
    public let timespan: TimespanResult?  // nil if no log entries
}

public struct TimespanResult {
    public let start: Date   // rounded to 15 min
    public let end: Date?    // nil if only one entry
}
```
