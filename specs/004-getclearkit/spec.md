# Feature Specification: GetClearKit Shared Infrastructure

**Feature Branch**: `003-color-output` (initial ANSI), then subsequent migrations
**Created**: 2026-03-14 (ANSI), 2026-03-15 (Fail, Flags, DateParser, RangeParser)
**Status**: Shipped (all phases complete by 2026-03-15; test suite at 235 tests as of 2026-03-19)
**Input**: Five tool repos were duplicating ANSI color logic, error printing, flag handling, and date/range parsing. Any bug fix or improvement required the same change in five places. GetClearKit is the shared Swift package that centralizes all of this.

> Note: ANSI, Fail, and Flags are also covered in the 003-color-output spec, which focuses on the UI experience. This spec covers GetClearKit as a package — the contract, the test infrastructure, and the date/range parsing that 003 does not address.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — A new tool gets color, errors, and flag handling for free (Priority: P1)

A developer adding a sixth tool to the suite imports GetClearKit and immediately has: bold/dim/red ANSI output that auto-suppresses when piped, a shared `fail()` that exits non-zero to stderr, and `--help`/`--version` flag dispatch. There is no color logic to write, no error printing to design, no flag variants to handle. The tool is correct from the first line.

**Why this priority**: The cost of duplicated logic compounds. Before GetClearKit, five copies of `ansiEnabled` existed — only some checked `isatty`. Getting the sixth copy right would be a coin flip. Shared infrastructure means "correct by default."

**Independent Test**: Create a new Swift executable, add `GetClearKit` to `Package.swift`, import it, and call `ANSI.bold("hello")`, `fail("test error")`, and `isHelpFlag("--help")`. All three compile and behave correctly without any additional logic.

**Acceptance Scenarios**:

1. **Given** a new tool that imports GetClearKit, **When** output is piped to `cat`, **Then** ANSI codes are absent — no per-tool isatty check required.
2. **Given** `fail("bad argument")` is called, **When** the tool runs, **Then** "Error: bad argument" appears in red on stderr and the process exits 1 — no per-tool error printing required.
3. **Given** `isHelpFlag(args[0])` is true, **When** the tool dispatches, **Then** usage output is shown — no per-tool string comparisons for `--help`/`-h`/`help` required.

---

### User Story 2 — Date input works the same everywhere (Priority: P1)

The user says "remind me friday at 3pm" or "check next week's calendar". Reminders and calendar parse these identically — same logic, same behavior, same edge-case handling. Before GetClearKit, reminders had its own date parser and calendar had its own range parser. A bug fix in one did not fix the other.

**Why this priority**: Users build mental models. If "next friday" works in reminders but not calendar, the suite feels broken. Shared parsing is the only way to guarantee consistent behavior.

**Independent Test**: Run `reminders add "Test" friday at 3pm` and `calendar list friday`. Both should interpret "friday" as the same upcoming Friday. Change the date to a month+day combo — both should agree.

**Acceptance Scenarios**:

1. **Given** `"friday at 3pm"` as input, **When** either reminders or calendar parses it, **Then** both return the same Date value.
2. **Given** `"march 15"` as input with no year, **When** parsed, **Then** the date rolls to next year if March 15 has already passed — same behavior in reminders and calendar.
3. **Given** `"this week"` as a range, **When** calendar parses it, **Then** it returns Monday through Sunday of the current week — same as `"week"` and `"this week"`.
4. **Given** `"march 10 to march 20"` as a range, **When** calendar parses it, **Then** it returns a range spanning those two inclusive dates.

---

### User Story 3 — Tests catch regressions before they ship (Priority: P1)

GetClearKit has its own test suite, independent of any tool's tests. A change to DateParser or RangeParser is validated before any tool binary is built. The test suite runs in CI on every push.

**Why this priority**: Shared infrastructure is load-bearing. A regression in GetClearKit breaks every tool simultaneously. Unit tests at the package level catch these before they reach users.

**Independent Test**: Run `swift run getclearkit-tests` from the get-clear repo root. All 235 tests pass. Break a date parsing case (e.g., comment out the abbreviated month dictionary) — the relevant tests fail and identify the regression immediately.

**Acceptance Scenarios**:

1. **Given** a change to `DateParser.swift`, **When** CI runs, **Then** the GetClearKit test job runs before any tool build job.
2. **Given** a failing GetClearKit test, **When** CI runs, **Then** the build jobs are blocked — a broken shared library cannot ship.
3. **Given** all tests pass, **When** a release is published, **Then** the test count is verifiable from CI logs — no silent skips.

---

### Edge Cases

**The isatty bug in the four original tools**
Before GetClearKit, reminders-cli and calendar-cli checked `NO_COLOR` but not `isatty`. contacts-cli was the first tool wired to GetClearKit and got the correct check from the start. The bug was diagnosed during that integration — contacts worked correctly because `ANSI.enabled` checked both. The other four tools retained their local (broken) helpers until the March 15 migration.

**Tombstone files**
`RemindersLib/DateParsing.swift` and `CalendarLib/TimeRangeParser.swift` were replaced by GetClearKit but kept as tombstone comments (not deleted) to preserve git blame history. The tombstones explain where the logic moved. This is intentional — deleting them loses the migration trail.

**Test targets vs. lib targets**
Both RemindersLib and CalendarLib are pure targets (no Apple framework deps, no GetClearKit dependency). Only the CLI binary targets and test targets import GetClearKit. This keeps the lib targets testable in isolation and prevents circular dependencies.

**`ANSI.enabled` is a stored property**
Color state is evaluated once at process startup. It is not re-evaluated per call. This is a deliberate performance choice — checking isatty on every `bold()` call would be unnecessary overhead. The consequence: color cannot be toggled mid-process. This is acceptable; no use case requires it.

**Abbreviated months were a late addition**
The initial `DateParser.swift` included full month names but not abbreviations (`jan`–`dec`). This caused `"Mar 20, 2026"` (the format `EKReminder.completionDate` produces when formatted) to fail parsing. Bug filed as reminders-cli #16 on 2026-03-19, fixed same day by adding the 3-letter abbreviations to the months dictionary. 10 new tests added; suite grew from 185 to 235 total across GetClearKit.

**US slash format and explicit year**
`3/10/2027`, `3/10/27`, `3/15`, and `3-15` were added to support Claude's natural date formats. The heuristic: if the first component is > 31, treat as ISO (Y/M/D); otherwise treat as US (M/D/Y). Two-digit years are assumed 2000+.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: GetClearKit MUST be a Swift package library target in the get-clear umbrella repo (`Sources/GetClearKit/`), importable by all five tool repos via `Package.swift` dependency.
- **FR-002**: `ANSI.enabled` MUST be a stored computed property, evaluated once at startup. It MUST return false when `NO_COLOR` is set (any value) OR when `isatty(STDOUT_FILENO)` returns 0. It MUST NOT be re-evaluated per call.
- **FR-003**: `ANSI.bold()`, `ANSI.dim()`, `ANSI.red()` MUST be identity functions (return the string unchanged) when `ANSI.enabled` is false.
- **FR-004**: `fail(_ msg: String) -> Never` MUST print `"Error: \(msg)"` in red to stderr and exit with code 1. It MUST be declared `Never` so the compiler enforces that callers do not continue after it.
- **FR-005**: `isVersionFlag(_ s: String) -> Bool` MUST match `"--version"`, `"-v"`, and `"version"`. `isHelpFlag(_ s: String) -> Bool` MUST match `"--help"`, `"-h"`, and `"help"`.
- **FR-006**: `parseDate(_ input: String) -> ParsedDate?` MUST support: `today`, `tomorrow`, weekday names, `next`/`this` weekday, `march 15`, `mar 15`, `march 10 2027`, `march 10, 2027`, `10 march 2027`, `2026-03-15`, `3/10/2027`, `3/10/27`, `3/15`, `3-15`, time-only (`3pm`, `14:30`), and combined (`friday at 5pm`).
- **FR-007**: `ParsedDate` MUST carry `hasTime: Bool` (true when input explicitly included a time) and `hasDate: Bool` (false for time-only input, where date defaults to today).
- **FR-008**: Month-only dates (`march 15`, `3/15`) MUST roll to next year if the date is in the past.
- **FR-009**: `parseRange(_ input: String) -> ParsedRange?` MUST support: `today`, `tomorrow`, `yesterday`, weekday names, month+day, ISO date, short date, `week`/`this week`/`next week`/`last week`, `month`/`this month`/`next month`/`last month`, `Nd` (N-day window), and `<date> to <date>` explicit ranges.
- **FR-010**: `ParsedRange` MUST carry `start: Date`, `end: Date` (end of day of the last day, 23:59:59), and `isSingleDay: Bool`.
- **FR-011**: `formatRangeDescription(_ range: ParsedRange) -> String` MUST return `"Monday, March 15"` for single-day ranges and `"Mar 15 – Mar 20"` for multi-day ranges (same-year) or `"Mar 15, 2026 – Jan 5, 2027"` for cross-year ranges.
- **FR-012**: GetClearKit MUST have its own test target (`getclearkit-tests` executable) runnable via `swift run getclearkit-tests`. Tests MUST NOT depend on any Apple EventKit or CalendarKit framework.
- **FR-013**: The GetClearKit test job MUST run in CI before any tool build job (`needs: getclearkit-tests`).

### Key Entities

- **`ANSI`**: Public enum in `ANSI.swift`. `enabled: Bool` (stored computed property, checked once at startup), `bold()`, `dim()`, `red()` (identity functions when disabled).
- **`fail(_ msg: String) -> Never`**: Free function in `Fail.swift`. Red "Error:" to stderr, exit 1.
- **`isVersionFlag(_ s: String) -> Bool`** / **`isHelpFlag(_ s: String) -> Bool`**: Free functions in `Flags.swift`.
- **`ParsedDate`**: Struct with `date: Date`, `hasTime: Bool`, `hasDate: Bool`.
- **`parseDate(_ input: String) -> ParsedDate?`**: Free function in `DateParser.swift`.
- **`formatDate(_ date: Date, showTime: Bool) -> String`**: Formats a date using `DateFormatter` with `.medium` date style.
- **`ParsedRange`**: Struct with `start: Date`, `end: Date`, `isSingleDay: Bool`.
- **`parseRange(_ input: String) -> ParsedRange?`**: Free function in `RangeParser.swift`.
- **`parseSingleDate(_ s: String, cal: Calendar, now: Date) -> Date?`**: Public helper — used by `parseRange` for each side of explicit ranges; also used directly by tools.
- **`formatRangeDescription(_ range: ParsedRange) -> String`**: Formats a range for display headers.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `swift run getclearkit-tests` passes all 235 tests with zero failures.
- **SC-002**: No tool repo contains inline ANSI helpers, a local `fail()`, manual flag string comparisons, or date/range parsing logic. All five repos are clean.
- **SC-003**: A breaking change to `DateParser.swift` produces a failing test in the GetClearKit suite before any tool binary can be built.
- **SC-004**: The same date input (e.g., `"friday at 3pm"`) produces identical behavior in `reminders add` and `calendar list`.
- **SC-005**: All five tools suppress ANSI codes when piped — verified via `<tool> list | cat` producing clean text.
- **SC-006**: GetClearKit CI job is a required check (not optional) — a failing test blocks all six release workflows.

## Design Notes

**The package, not just the helpers.** GetClearKit is not a utility bag. It is the shared contract of the suite — every capability in it is available to every tool without duplication. The rule: if the same logic appears in two tool repos, it belongs in GetClearKit first. This rule applies even for small utilities like `fail()`.

**Tests live in the umbrella repo, not in tool repos.** GetClearKit tests are owned by the get-clear repo. Tool repos (reminders, calendar) import GetClearKit for their own tests (e.g., reminders-tests validates that `parseOptions` integrates correctly with `parseDate`), but the canonical date and range parser tests live in the shared suite.

**Tombstone files preserve history.** When `DateParsing.swift` was removed from RemindersLib and `TimeRangeParser.swift` was removed from CalendarLib, the files were replaced with a comment explaining where the logic moved. Deleting them silently would make `git blame` harder. The tombstones are intentional artifacts.

**Two-digit years assumed 2000+.** `3/10/27` is parsed as 2027. This is the correct heuristic for the foreseeable future and avoids the question of which century a user means. Revisit in 2075.

**`parseSingleDate` is public.** The range parser needed a single-date helper for each side of "X to Y". That helper was made public so tools can also call it directly (e.g., for a single-event lookup by date). This is an intentional part of the public API, not an implementation leak.

## Assumptions

- GetClearKit targets macOS only. `STDOUT_FILENO` and `isatty()` are POSIX and available on all supported targets.
- The test suite runs via a Swift executable target (`getclearkit-tests`), not `swift test`, because the executable pattern allows tests to use EventKit-free Apple Foundation without XCTest framework overhead.
- All date parsing uses `Calendar.current` (the user's local calendar) and `Date()` (current time). No timezone override is provided — the user's system timezone is always correct.
- The "roll to next year if past" rule applies to bare month+day inputs. Inputs with explicit years never roll.
