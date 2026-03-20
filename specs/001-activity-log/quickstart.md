# Implementation Quickstart

## What gets built

Five additions, in dependency order:

1. **GetClearKit** — `ActivityLog.swift`, `ActivityLogReader.swift`, `RecapAggregator.swift`, `TimespanFormatter.swift` + tests
2. **Five tool Libs** — add `ActivityLog.write()` call after each successful write command
3. **Five tool CLIs** — add `what [range]` dispatch
4. **get-clear binary** — new executable target in umbrella repo; `what [range]` and `recap [range]`
5. **Package.swift** — add `GetClear` executable target; add EventKit entitlement

## Build order matters

GetClearKit must be complete and tested before any tool changes. The tool Lib changes are independent of each other once GetClearKit is ready. The get-clear binary is last — it depends on GetClearKit and needs EventKit entitlement in place.

## Key files to create

| File | Repo | Purpose |
|---|---|---|
| `Sources/GetClearKit/ActivityLog.swift` | get-clear | POSIX append writer |
| `Sources/GetClearKit/ActivityLogReader.swift` | get-clear | JSONL parser + range filter |
| `Sources/GetClearKit/RecapAggregator.swift` | get-clear | Filter to commitments, suppress pairs, group |
| `Sources/GetClearKit/TimespanFormatter.swift` | get-clear | Round to 15 min, format range string |
| `Sources/GetClear/main.swift` | get-clear | `what` and `recap` dispatch |
| `Tests/GetClearKitTests/ActivityLogTests.swift` | get-clear | All GetClearKit log tests |

## Key files to modify

| File | Repo | Change |
|---|---|---|
| `Sources/RemindersLib/*.swift` | reminders-cli | Add `ActivityLog.write()` after each successful command |
| `Sources/RemindersCLI/main.swift` | reminders-cli | Add `what` dispatch |
| `Package.swift` | get-clear | Add `GetClear` executable target |
| *(same pattern for calendar, contacts, mail, sms)* | | |

## Critical constraints

- **Log write must never fail the command** — wrap in `try? ActivityLog.write(...)`, silently drop on error
- **System clock only** — never accept a timestamp from an argument or environment variable
- **POSIX O_APPEND** — do not use `FileHandle.seekToEndOfFile()`
- **All-day events use date comparison** — check `startDate` calendar date, not `endDate <= now`
- **No suppression logic needed** — recap queries live data stores; cancelled items aren't present

## Testing approach

GetClearKit tests cover:
- Write produces valid JSONL line
- Reader parses and filters by tool, date, command
- RecapAggregator groups correctly, suppresses add/remove pairs
- TimespanFormatter rounds correctly (boundary cases: X:07 → X:00, X:08 → X:15)
- Empty range returns correct empty result

Per-tool `what` tests: verify command dispatches, correct range is passed, output format matches contract.

The get-clear binary EventKit integration is tested manually (EventKit requires device/simulator).
