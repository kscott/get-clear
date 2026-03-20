# Feature Specification: Multi-Match Disambiguation

**Feature Branch**: `main` (commit 88ec451, 2026-03-10)
**Created**: 2026-03-10
**Status**: Shipped (2026-03-10; reminders-cli; same pattern referenced in calendar-cli remove)
**Input**: When a user has two reminders with the same title in different lists — e.g., "Review docs" in both Ibotta and Personal — `reminders change "Review docs" ...` had no way to know which one to act on. Before this fix, it would either fail silently or act on the first match. The fix: when multiple matches exist and no list is specified, show a numbered candidate list and suggest the disambiguating command.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Duplicate titles across lists show candidates (Priority: P1)

The user has "Pay rent" in both Personal and Household Finances. They run `reminders done "Pay rent"`. Instead of acting on one arbitrarily or failing silently, the tool lists both candidates with their list names and tells the user to narrow with a list argument. The user reruns with `reminders done "Pay rent" "Household Finances"` and the correct reminder is marked done.

**Why this priority**: Acting on the wrong reminder is a data integrity error. Failing silently is confusing. The numbered candidate list is the honest response — it tells the user exactly what was found and exactly how to disambiguate.

**Independent Test**: Create two reminders with the same title in different lists. Run `reminders change "<title>" date tomorrow`. Verify: the tool lists both candidates with list names and exits without making any change. Add the list name argument and verify the correct reminder is changed.

**Acceptance Scenarios**:

1. **Given** two reminders with the same title in different lists, **When** `reminders change/rename/done/remove/show` is called without a list, **Then** both candidates are shown with their list names and no action is taken.
2. **Given** the candidate list, **When** the user reruns with a list argument, **Then** the correct reminder is found and the operation succeeds.
3. **Given** a title that exists in only one list, **When** `reminders change/rename/done/remove/show` is called without a list, **Then** the operation proceeds normally — no disambiguation prompt.
4. **Given** a title that matches no reminder, **When** any of these commands runs, **Then** a clear "not found" error is shown.

---

### Edge Cases

**Disambiguation is for these five commands only**
`find` uses partial/contains matching by design — it's a search command. Only `show`, `change`, `rename`, `done`, and `remove` require exact case-insensitive matching and trigger disambiguation when multiple records match.

**The suggestion tells the user what to type**
The disambiguation output includes the suggested command with the list argument filled in. This is intentional — the user should not need to figure out the syntax, they should be able to copy-paste or retype with minimal effort.

**Calendar remove uses the same pattern**
`calendar remove <title> [date]` also shows candidates when multiple events match the title. The pattern is suite-wide: when exact matching finds multiple records, list candidates and exit without acting.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When `show`, `change`, `rename`, `done`, or `remove` matches multiple reminders by title (case-insensitive, exact), the tool MUST list all candidates with their list names and exit without performing any action.
- **FR-002**: The candidate list MUST show each reminder's title and list name. The disambiguation suggestion MUST include the corrected command syntax with the list argument.
- **FR-003**: When a single match is found, the operation MUST proceed without any disambiguation prompt.
- **FR-004**: When no match is found, a clear "not found" error MUST be shown.
- **FR-005**: The user MUST be able to disambiguate by adding the list name as an argument: `reminders <cmd> "<title>" "<list>"`.

### Key Entities

- **Exact case-insensitive match**: The lookup mechanism for `show`/`change`/`rename`/`done`/`remove`. Different from `find`'s partial/contains match.
- **Candidate list**: Output when multiple reminders share a title — lists each with its list name; suggests the disambiguation command.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `reminders done "Pay rent"` with two matches shows candidates without marking anything done.
- **SC-002**: `reminders done "Pay rent" "Household Finances"` with two matches in different lists marks the correct one done.
- **SC-003**: `reminders done "Unique title"` with one match marks it done without a disambiguation prompt.
- **SC-004**: No reminder is ever modified when multi-match disambiguation triggers.

## Design Notes

**Disambiguation is protective, not annoying.** The alternative — act on the first match — would silently corrupt data when duplicate titles exist. The candidate list stops the operation and gives the user the information they need to proceed correctly. The cost (a re-run) is small; the benefit (no wrong action) is large.

**Exact matching is a deliberate contrast with `find`.** `find` is for browsing — "show me everything about rent." `show`/`change`/`done`/`remove` are for acting — "do this specific thing." The matching semantics reflect the intent. This distinction is documented in the suite vocabulary.

## Assumptions

- Reminder titles are not unique system-wide — users commonly have the same reminder title in multiple lists.
- The list name is always a reliable disambiguator. If the same title appears twice in the same list, the behavior is undefined (EventKit should not allow this, but if it does, the first match wins).
