# Feature Specification: Date Parsing Extensions

**Feature Branch**: `main` (commits 8be5b9f, 803a11c, and surrounding; 2026-03-15 and 2026-03-19)
**Created**: 2026-03-15 (explicit year and US slash); 2026-03-19 (abbreviated months)
**Status**: Shipped (all extensions in GetClearKit DateParser.swift; 235 tests passing)
**Input**: The initial date parser handled relative dates (today, tomorrow, weekdays) and bare month+day ("march 15"). Three gaps emerged from real use: (1) Claude sometimes writes explicit years ("march 10 2027") when setting far-future dates; (2) US slash format ("3/10/2027") is a natural format Claude and users both use; (3) EventKit formats completion dates as "Mar 20, 2026" (abbreviated month) for the `get-clear recap` command, which the parser rejected.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Explicit year prevents date rollover for far-future dates (Priority: P1)

The user says "add a reminder for March 10, 2027." Claude calls `reminders add "..." "march 10 2027"`. The parser returns March 10, 2027 — not March 10 of the current year, not next-year rollover. The year is explicit, so no inference is needed.

**Why this priority**: For dates more than a year out, the roll-to-next-year heuristic fails — "march 15" will roll to next year only if today is after March 15, but "march 15 2027" is unambiguous. Explicit year support is essential for long-range planning.

**Independent Test**: Run `reminders add "Long-term task" march 10 2027`. Verify the reminder is due March 10, 2027, regardless of what the current date is.

**Acceptance Scenarios**:

1. **Given** `"march 10 2027"` as input, **When** parsed, **Then** the result is March 10, 2027 — year is used as-is, no rollover.
2. **Given** `"march 10, 2027"` (with comma), **When** parsed, **Then** same result — commas are trimmed.
3. **Given** `"10 march 2027"` (day-month-year order), **When** parsed, **Then** same result — day-first order is supported.
4. **Given** `"march 10 27"` (two-digit year), **When** parsed, **Then** result is March 10, 2027 — two-digit years are 2000+.

---

### User Story 2 — US slash format works for explicit dates (Priority: P1)

Claude writes "3/10/2027" when the user says "March 10th 2027" in conversation. This format passes through to `reminders add` and parses correctly. Short dates ("3/15", "3-15") also work and roll to next year if past.

**Why this priority**: US slash format is one of the most common date formats in English-language contexts. Claude uses it naturally. If it doesn't parse, any reminder with a slash date silently fails.

**Independent Test**: Run `reminders add "Test" 3/10/2027`. Verify the reminder is due March 10, 2027. Run `reminders add "Test" 3/15` — verify it's due this March 15 (or next year if past).

**Acceptance Scenarios**:

1. **Given** `"3/10/2027"`, **When** parsed, **Then** result is March 10, 2027 (US M/D/Y format, first component ≤ 31).
2. **Given** `"2026-03-15"` (ISO), **When** parsed, **Then** result is March 15, 2026 (first component > 31 → Y/M/D).
3. **Given** `"3/15"` or `"3-15"` (no year), **When** parsed, **Then** result is March 15 of the current or next year (roll if past).
4. **Given** `"3/10/27"` (two-digit year), **When** parsed, **Then** result is March 10, 2027.

---

### User Story 3 — Abbreviated months parse correctly for recap (Priority: P1)

`get-clear recap` reads completed reminders from EventKit. EventKit formats `completionDate` as `"Mar 20, 2026"` when formatted with `DateFormatter` medium style. The recap feature calls `parseDate` on this string to extract the date. If abbreviated months fail, the recap shows no completed reminders — a silent failure.

**Why this priority**: This was an active bug (reminders-cli #16) that caused `get-clear recap` to silently omit completed reminders. The fix is small (adding 3-letter abbreviations to the months dictionary) but the impact is large — without it, the "commitments kept" summary is always empty.

**Independent Test**: Complete a reminder in Reminders.app. Run `get-clear recap today`. Verify the completed reminder appears in the "Tasks completed" section.

**Acceptance Scenarios**:

1. **Given** `"Mar 20, 2026"` (EventKit completion date format), **When** parsed, **Then** result is March 20, 2026.
2. **Given** any 3-letter month abbreviation (`jan` through `dec`), **When** it appears as the first word of a date string, **Then** it parses correctly.
3. **Given** `"mar 20"` without a year, **When** parsed, **Then** it rolls to next year if March 20 has passed — same behavior as `"march 20"`.

---

### Edge Cases

**The heuristic for US vs ISO slash format**
`3/10/2027` (US) and `2026/03/15` (ISO) are disambiguated by the value of the first component: if it's > 31, it must be a year (ISO); if ≤ 31, it's a month (US). This heuristic is correct for all realistic inputs — years are 4 digits, months are 1-2 digits.

**Comma trimming in month+day+year**
`"march 10, 2027"` has a comma after the day. The parser trims commas from all three parts before parsing. This handles the natural English date format "March 10, 2027" as Claude and users write it.

**`may` is a 3-letter month that doesn't need an abbreviation**
The 3-letter abbreviations added are: jan, feb, mar, apr, jun, jul, aug, sep, oct, nov, dec. `may` is already in the full-months dictionary (it's both the full name and the abbreviation). Adding it again is harmless.

**`"mar 20, 2026"` format comes from EventKit**
The bug was specific to EventKit's `DateFormatter.medium` output. This is an example of the suite consuming its own output — `recap` reads completion dates from EventKit, formats them via `DateFormatter`, and then needs to parse them back. The abbreviated month format was an unexpected loop.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `parseDate()` MUST accept `"month-name day year"` with 3- or full-name months and year as 2 or 4 digits. Commas between components MUST be trimmed.
- **FR-002**: `parseDate()` MUST accept `"day month-name year"` order (e.g., `"10 march 2027"`).
- **FR-003**: `parseDate()` MUST accept `"M/D/YYYY"`, `"M/D/YY"`, and `"YYYY-MM-DD"` (ISO). Disambiguation: first component > 31 → ISO.
- **FR-004**: `parseDate()` MUST accept `"M/D"` and `"M-D"` (no year) with roll-to-next-year if the date is past.
- **FR-005**: All 3-letter month abbreviations (`jan` through `dec`) MUST be recognized as valid month names, identical in behavior to their full-name equivalents.
- **FR-006**: Two-digit years MUST be interpreted as 2000+.
- **FR-007**: Explicit years MUST never roll — `"march 10 2027"` is always March 10, 2027, regardless of today's date.
- **FR-008**: New test coverage MUST be added for each new format. Abbreviated months: 10 tests minimum.

### Key Entities

- **`months` dictionary in `DateParser.swift`**: Maps full month names and 3-letter abbreviations to month numbers (1–12). Keys: `"january"` through `"december"` and `"jan"` through `"dec"`.
- **Three-component parsing branch**: Handles `"month day year"`, `"day month year"`, and trims commas from all components.
- **Slash/dash parsing branch**: Heuristic split for US vs ISO vs short-date formats.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `swift run getclearkit-tests` passes all 235 tests including 10 new abbreviated-month tests.
- **SC-002**: `reminders add "Test" march 10 2027` creates a reminder due March 10, 2027.
- **SC-003**: `reminders add "Test" 3/10/2027` creates a reminder due March 10, 2027.
- **SC-004**: `get-clear recap today` lists completed reminders — abbreviated month parsing no longer silently drops them.
- **SC-005**: `reminders add "Test" mar 20` creates a reminder due March 20 (current or next year).

## Design Notes

**The bug was in the consumer, found via production use.** The abbreviated month gap was not caught in initial testing because the test suite used full month names. It was discovered when `get-clear recap` silently showed no completed reminders despite the user having completed reminders that day. The fix required tracing the data flow: EventKit → `DateFormatter` → `parseDate` — and recognizing that `DateFormatter.medium` produces abbreviated months.

**Each format addition gets tests before ship.** The date parser is load-bearing infrastructure — wrong parsing causes silent data corruption (wrong reminder dates). New format support always ships with tests that cover the format explicitly. The 10 abbreviated-month tests are an example of this discipline.

**`formatDate` uses `DateFormatter.medium` which produces abbreviated months.** This is the root of the loop: `formatDate()` in GetClearKit uses `dateStyle: .medium`, which produces "Mar 20, 2026". When `recap` feeds this output back into `parseDate()`, abbreviated months must parse. The suite was consuming its own formatting conventions.

## Assumptions

- All date parsing uses the user's local `Calendar.current` and local timezone. No UTC normalization.
- Two-digit years < 100 are always 2000+. A year like `"26"` means 2026.
- The full-name months dictionary is case-insensitive (all inputs are lowercased before matching). Abbreviations follow the same lowercasing.
