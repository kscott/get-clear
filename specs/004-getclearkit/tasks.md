# Tasks: GetClearKit Shared Infrastructure

All tasks complete. Shipped across multiple sessions 2026-03-14 through 2026-03-19.

---

## Phase 1 — Package creation and ANSI (2026-03-14)

- [x] **T001** — Create GetClearKit Swift package in get-clear umbrella repo: `Package.swift`, `Sources/GetClearKit/` target
- [x] **T002** — `ANSI.swift`: `ANSI.enabled` (stored computed property, isatty + NO_COLOR), `bold()`, `dim()`, `red()`
- [x] **T003** — Wire contacts-cli as first consumer: add dependency, import GetClearKit, remove inline helpers

---

## Phase 2 — Fail, Flags, DateParser (2026-03-15)

- [x] **T004** — `Fail.swift`: `fail(_ msg: String) -> Never` — red "Error:" prefix to stderr, exit 1; closed get-clear #12
- [x] **T005** — `Flags.swift`: `isVersionFlag()`, `isHelpFlag()` — all three string variants each; closed get-clear #13
- [x] **T006** — `DateParser.swift`: migrate natural-language date parsing from `RemindersLib/DateParsing.swift` to GetClearKit; closed get-clear #11
  - Supports: today, tomorrow, weekdays, next/this weekday, month+day, ISO, US slash, short date, time-only, combined
  - `ParsedDate` struct with `hasTime` and `hasDate` flags
  - Roll-to-next-year for bare month+day when date is past
- [x] **T007** — `RemindersLib/DateParsing.swift` → tombstone comment (logic moved to GetClearKit)
- [x] **T008** — `RangeParser.swift`: migrate time-range parsing from `CalendarLib/TimeRangeParser.swift` to GetClearKit
  - Supports: single days, weekdays, week/month spans (this/next/last), N-day windows, explicit ranges
  - `ParsedRange` struct with `start`, `end`, `isSingleDay`
  - `parseSingleDate()` extracted as public helper
  - `formatRangeDescription()` for display headers
- [x] **T009** — `CalendarLib/TimeRangeParser.swift` → tombstone comment (logic moved to GetClearKit)
- [x] **T010** — GetClearKit test suite: `Tests/GetClearKitTests/main.swift` executable with 185 tests covering DateParser and RangeParser
- [x] **T011** — `swift run getclearkit-tests` integration: test target defined in `Package.swift`, runnable as `getclearkit-tests` product

---

## Phase 3 — CI integration (2026-03-15)

- [x] **T012** — Add `getclearkit-tests` job to get-clear CI workflow
- [x] **T013** — All five tool build jobs declare `needs: getclearkit-tests` — failing tests block builds

---

## Phase 4 — Abbreviated months fix (2026-03-19)

- [x] **T014** — Add 3-letter month abbreviations (jan–dec) to months dictionary in `DateParser.swift`; closes reminders-cli #16
- [x] **T015** — Add 10 new tests for abbreviated months; suite grows from 185 → 235 (across GetClearKit and reminders-lib)

---

## Tool migrations (2026-03-15)

*All five tools migrated from inline helpers to GetClearKit in one pass.*

- [x] **T016** — reminders-cli: replace inline date parsing with `GetClearKit.parseDate()`
- [x] **T017** — reminders-cli: replace inline ANSI helpers, `fail()`, flag comparisons with GetClearKit equivalents
- [x] **T018** — calendar-cli: replace inline range parsing with `GetClearKit.parseRange()`
- [x] **T019** — calendar-cli: replace inline ANSI helpers, `fail()`, flag comparisons with GetClearKit equivalents
- [x] **T020** — mail-cli: replace inline ANSI helpers, `fail()`, flag comparisons with GetClearKit equivalents
- [x] **T021** — sms-cli: replace inline ANSI helpers, `fail()`, flag comparisons with GetClearKit equivalents

---

## Closed issues

- [x] **get-clear #11** — date parsing in GetClearKit
- [x] **get-clear #12** — shared `fail()` in GetClearKit
- [x] **get-clear #13** — standard flag handling in GetClearKit
- [x] **reminders-cli #16** — abbreviated month names in date parser
