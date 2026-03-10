# calendar-cli

Swift CLI tool for Apple Calendar via EventKit.

## Build & run

```bash
calendar setup   # build release binary and install to ~/bin
calendar test    # build and run test suite
```

Or directly via SPM:
```bash
swift build -c release   # build release
swift build              # build debug (needed before running tests)
```

## Project structure

- `Sources/CalendarLib/TimeRangeParser.swift` — pure range parsing logic, no framework deps
- `Sources/CalendarLib/ConfigParser.swift` — pure TOML subset config parsing, no framework deps
- `Sources/CalendarCLI/main.swift` — CLI entry point, all EventKit/AppKit code
- `Tests/CalendarLibTests/main.swift` — custom test runner (no Xcode/XCTest required)
- `calendar` — bash wrapper script, symlinked into `~/bin`

See [DEVELOPMENT.md](DEVELOPMENT.md) for coding conventions, interface design rules, and patterns to follow when adding features.

## Key decisions

- **EventKit over AppleScript** — same rationale as reminders-cli; faster, non-blocking UI
- **CalendarLib separated from CalendarCLI** — allows unit testing without entitlements or permissions
- **Custom test runner instead of XCTest** — works with CLT only, no full Xcode needed
- **`store.events(matching:)` is synchronous** — unlike reminders (async fetch), event queries are sync after access is granted; the semaphore is only needed for the access callback
- **External calendars work** — EventKit sees any calendar configured in Calendar.app (Google, Exchange, etc.)
- **Named subsets in config** — `~/.config/calendar-cli/config.toml` maps subset names to calendar title lists; `--cal` accepts either a subset name or a literal calendar name
- **`calendar` bare command + range** — unrecognised commands are tried as range shorthands; `calendar monday`, `calendar 7d`, `calendar "march 15"` all work without an explicit `list`

## Commands

```
calendar open
calendar calendars
calendar list <range> [--cal <subset>]
calendar today [--cal <subset>]
calendar week [--cal <subset>]
calendar next [n] [--cal <subset>]
calendar find <query> [range] [--cal <subset>]
calendar show <title> [date]
calendar add <title> [date] [time to time] [--cal <name>]
calendar remove <title> [date] [--cal <name>]
```

Bare range shorthands also work: `calendar monday`, `calendar 7d`, `calendar "march 15"`, etc.

## Range syntax

```
today, tomorrow, yesterday
week, this week, next week, last week
month, this month, next month, last month
monday … sunday           (next occurrence, or today if today matches)
"march 15", "2026-03-15"  (specific date)
"3/15", "3-15"            (short numeric, rolls to next year if past)
7d, 30d                   (N days from today)
"march 15 to march 20"    (explicit range, any two single-date expressions)
```

## Calendar filter (--cal)

`--cal` accepts either a named subset (from config.toml) or a literal calendar title. Subset matching is case-insensitive.

Config file: `~/.config/calendar-cli/config.toml`
```toml
[subsets]
work     = ["Work", "Meetings", "Ken's Google Calendar"]
personal = ["Home", "Family", "Birthdays & Anniversaries"]
church   = ["Trinity UMC"]
```

## Known limitations

- `add` targets the first calendar in the `--cal` set, or the system default
- `show` and `remove` list candidates when multiple events match; narrow with a date
- Attendee info only present for events with invitations (not personal events)
- Requires macOS 14+

## Deployment

Binary lives at `~/bin/calendar-bin`. The `calendar` wrapper in this repo is symlinked there.
On a new machine, run `~/dev/calendar-cli/calendar setup` after cloning.
