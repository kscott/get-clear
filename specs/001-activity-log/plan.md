# Implementation Plan: Activity Log, What, and Recap

**Branch**: `001-activity-log` | **Date**: 2026-03-19 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-activity-log/spec.md`

## Summary

Add a persistent activity log to all five tools and expose it through two new commands: `what` (raw chronological log, per-tool and suite-wide) and `recap` (suite-level commitments-kept summary with calendar query). The log is written by each tool's Lib layer after every successful write command, stored as daily files in `~/.local/share/get-clear/log/`. Shared logic — writer, reader, recap aggregation, timespan formatting — lives in GetClearKit. A new `get-clear` suite-level binary in the umbrella repo hosts `what` and `recap`.

## Technical Context

**Language/Version**: Swift 5.9+
**Primary Dependencies**: GetClearKit (shared log logic), EventKit (calendar past-event query in `recap`), Foundation (file I/O, date handling)
**Storage**: Append-only daily log files — `~/.local/share/get-clear/log/YYYY-MM-DD.log` — JSON Lines format (one JSON object per line)
**Testing**: XCTest via `swift test`; log writer/reader/aggregator tested in GetClearKit test suite
**Target Platform**: macOS 13+ (consistent with suite)
**Project Type**: Library additions (GetClearKit) + CLI additions (five tools) + new CLI binary (get-clear umbrella)
**Performance Goals**: Log write completes in <100ms; `get-clear what` returns in <1s for any single day (SC-002)
**Constraints**: No network calls for log operations; system clock only for timestamps (FR-016); log directory auto-created (FR-014); concurrent writes from multiple tool instances must not corrupt the log
**Scale/Scope**: Personal tool, single user, ~50–200 log entries/day typical

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Two Equal Modes | ✅ Pass | `what` and `recap` are natural to type directly and read well |
| II. Conversational Vocabulary | ✅ Pass | `what` and `recap` survive translation; tone/brevity rules apply to output |
| III. Add/Remove Symmetry | ✅ N/A | No new record types created by this feature |
| IV. Tool Identity | ✅ Pass | Log write is write-behind for all tools; `what`/`recap` are read-only, fire no side effects |
| V. Lib/CLI Architecture | ⚠️ Review | Log writer must live in each tool's Lib (not main.swift). Per-tool `what` display in CLI layer. Verify during design. |
| VI. Shared Logic in GetClearKit | ✅ Pass | Log writer, reader, recap aggregator, timespan formatter all go in GetClearKit — used by all six targets |
| VII. No Dead Code | ✅ Pass | All new code serves active requirements; no stubs |
| VIII. Error Output Design | ✅ Pass | Log write failures, corrupt files, calendar permission denial each need case-appropriate treatment |

## Project Structure

### Documentation (this feature)

```text
specs/001-activity-log/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code — changes across repos

```text
get-clear/Sources/GetClearKit/
├── ActivityLog.swift          # Log writer — append entry, create directory
├── ActivityLogReader.swift    # Log reader — parse entries, filter by tool/date/command
├── RecapAggregator.swift      # Recap logic — filter to commitments, suppress add/remove pairs, group by type
└── TimespanFormatter.swift    # Round timestamps to 15 min, format "9:00am → 4:45pm"

get-clear/Sources/GetClear/   # New suite-level CLI binary
└── main.swift                 # Dispatches: what [range], recap [range]

get-clear/Tests/GetClearKitTests/
└── ActivityLogTests.swift     # Writer, reader, aggregator, timespan tests

reminders-cli/Sources/RemindersLib/
└── [each command] — add ActivityLog.write() after successful action

reminders-cli/Sources/RemindersCLI/
└── main.swift — add `what [range]` dispatch

calendar-cli/  contacts-cli/  mail-cli/  sms-cli/
└── [same pattern as reminders-cli]
```

**Structure Decision**: GetClearKit owns all shared log logic. Five tool repos each add write calls to their Lib and a `what` command to their CLI. The umbrella repo gains a new `GetClear` executable target for `get-clear what` and `get-clear recap`. No tool logic is duplicated.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| New binary target in umbrella repo | `recap` needs cross-tool log aggregation + EventKit access in one command | Per-tool recap would lose the suite-wide view that makes it meaningful; shell script would bypass Swift type safety and GetClearKit |
