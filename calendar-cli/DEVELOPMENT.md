# Development conventions

Follows the same patterns as reminders-cli. Read that project's DEVELOPMENT.md as the canonical reference. Differences and additions specific to calendar-cli are noted below.

## Architecture: what goes where

**`CalendarLib`** — pure Swift, no framework dependencies
- `ConfigParser.swift` — TOML config loading into `CalendarConfig`
- `CalendarResolver.swift` — `resolveCalendarIdentifiers()`: subset filter → identifiers (no store access)
- `EventDateTime.swift` — `parseEventDateTime()`: date/time string → structured start/end/isAllDay
- `EventFormatter.swift` — `EventDisplayData`, `eventLine()`, `nextRelativeLabel()`, `printGrouped()`, `printFlat()`
- `RangeParser.swift` (from GetClearKit) — all range parsing

**`CalendarCLI/`** — EventKit and AppKit only
- `main.swift` — argument parsing and command dispatch
- `EventFetcher.swift` — `resolveCalendars()`, `fetchEvents()`, `calendarColor()`, `displayData()`
- `SetupCommand.swift` — `runSetup()`: interactive config wizard

## Interface design: one flag, no syntax

The tool uses positional arguments and natural language — not flags.

The one exception is `--cal`, which filters results to a named subset or specific calendar. It's necessary because there's no unambiguous positional way to distinguish a calendar name from a range argument.

## Range parsing

Ranges are parsed by `parseRange()` in `TimeRangeParser.swift`. All range inputs collapse to a `(start: Date, end: Date)` pair. `isSingleDay` tells the caller whether to use flat or grouped display.

The `default` case in `main.swift`'s command switch tries the full argument string as a range before falling through to `usage()`. This is what makes `calendar monday`, `calendar 7d`, etc. work without requiring the `list` subcommand.

## Output conventions

- **Single-day range**: day header line, then flat list of events below it
- **Multi-day range**: events grouped by day; empty days omitted; blank line between day groups
- **`next N`**: compact one-line-per-event format with relative date label + start time + title
- **`show`**: labelled field format, one field per line, aligned with two-space indent

Event lines: `  [start] – [end]   [title][ · location]`
All-day events: `  All day               [title][ · location]`
Start/end times are fixed-width columns for alignment.

## Testing

- All test-worthy logic lives in `CalendarLib`
- Tests in `Tests/CalendarLibTests/main.swift` — custom runner, no XCTest
- Run with `calendar test`
- New range format → new test suite with: valid inputs, edge cases, nil returns for garbage

## Adding a new command

1. Add the case to `switch cmd` in `main.swift`
2. Add to `usage()`
3. Add to command tables in `README.md` and `CLAUDE.md`
4. If it introduces new parsing logic, add to `CalendarLib` with tests
