# Feature Specification: List Moving (Reminders)

**Feature Branch**: `main` (commit 2d5d50c, 2026-03-16; closes reminders-cli #13)
**Created**: 2026-03-16
**Status**: Shipped (2026-03-16; 20 new tests; 200 total)
**Input**: `reminders change` could update due date, repeat, priority, note, and URL — but not which list a reminder belongs to. Moving a reminder between lists required removing it and re-adding it, which lost due date, notes, and repeat settings. The `list` keyword was added to `change` to enable in-place list moves.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Move a reminder to another list (Priority: P1)

The user asks Claude to move "Review the PRD" from Personal to Ibotta. Claude calls `reminders change "Review the PRD" list Ibotta`. The reminder moves to the Ibotta list with all its attributes intact — due date, priority, note, and repeat preserved. The source list name is optional; if the title is unique, it's found automatically.

**Why this priority**: Before this feature, the only workaround was `remove` + `add`, which discarded the reminder's due date, notes, repeat, and priority. Losing metadata silently is worse than not having the feature at all.

**Independent Test**: Add a reminder with a due date and note to list A. Run `reminders change "<title>" list B`. Verify the reminder appears in list B with the due date and note intact. Verify list A no longer contains the reminder.

**Acceptance Scenarios**:

1. **Given** `reminders change "Pay rent" list Ibotta`, **When** "Pay rent" exists in one list, **Then** it moves to Ibotta with all attributes preserved.
2. **Given** `reminders change "Pay rent" Personal list Ibotta`, **When** "Pay rent" exists in multiple lists, **Then** the one in Personal is moved to Ibotta; the other is untouched.
3. **Given** `reminders change "Pay rent" list Ibotta`, **When** "Ibotta" does not exist, **Then** a clear error is shown: "List not found: Ibotta".
4. **Given** `reminders change "Pay rent" list Ibotta date friday`, **When** both list and date are specified, **Then** both are applied in one operation.

---

### Edge Cases

**`list` as a keyword in `parseOptions`**
The `list` keyword was added to `parseOptions` using the same pattern as `repeat`, `priority`, `url` — it's a recognized keyword followed by its value. This means `list` cannot appear as a word in any other field. The collision space is small in practice.

**Source list is optional, but required for disambiguation**
If the title matches multiple reminders in different lists, the disambiguation prompt fires (spec 009) and no action is taken. The user re-runs with the source list to narrow: `reminders change "Pay rent" Personal list Ibotta`.

**The `nothing to change` error message was updated**
Before this feature, the error for no recognized keywords was "nothing to change — specify a date, repeat, priority, note, or url". The `list` keyword was added to this message: "nothing to change — specify a date, repeat, priority, note, url, or list".

**MCP server updated same session**
Immediately after shipping, the MCP server was updated to expose `target_list` as a typed parameter on `reminders_change`. This closed the loop: Claude can now move reminders via MCP without constructing shell strings.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `reminders change <title> [source-list] list <target-list>` MUST move the reminder to the target list while preserving all other attributes (due date, repeat, priority, note, URL).
- **FR-002**: `list` MUST be recognized as a keyword in `parseOptions`, following the same pattern as `repeat`, `priority`, `url`.
- **FR-003**: The target list lookup MUST be case-insensitive.
- **FR-004**: If the target list is not found, `fail("List not found: <name>")` MUST be called.
- **FR-005**: The change confirmation output MUST include the list move: `"list → <from> → <to>"`.
- **FR-006**: `list` MUST be combinable with other `change` keywords in a single invocation (e.g., `change "title" date friday list Ibotta`).
- **FR-007**: `reminders_change` in the MCP server MUST expose `target_list` as a typed optional string parameter.
- **FR-008**: 20 new tests MUST cover: basic move, move with source-list disambiguation, not-found error, combined list+date, and the `nothing to change` error message update.

### Key Entities

- **`ParsedOptions.list: String`**: New field in `ParsedOptions`, populated when `list <name>` appears in the change arguments.
- **`list` keyword in `parseOptions`**: Pattern: `("list", #"\blist\b"#)` — same mechanism as other keywords.
- **Target calendar lookup**: `store.calendars(for: .reminder).first(where: { $0.title.caseInsensitiveCompare(opts.list) == .orderedSame })`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `reminders change "Pay rent" list Ibotta` moves the reminder to Ibotta with due date, note, and priority intact.
- **SC-002**: `reminders change "Pay rent" Personal list Ibotta` when "Pay rent" exists in both Personal and Ibotta moves only the Personal one.
- **SC-003**: `reminders change "Pay rent" list Nonexistent` returns "Error: List not found: Nonexistent" and makes no change.
- **SC-004**: `swift run reminders-tests` passes all 200 tests including 20 new list-move tests.

## Design Notes

**`change` vs `remove`+`add` for list moving.** The workaround — `remove` then `add` — destroys metadata. `change` with `list` is the correct abstraction: it's a mutation, not a delete-and-recreate. The semantic choice (keyword `list` on `change`) is better than adding a `move` command because `change` already owns all attribute mutations.

**The keyword pattern scales.** Adding `list` to `parseOptions` took three lines: one field in `ParsedOptions`, one entry in the keyword table, and one handler in `main.swift`. This is evidence that the `parseOptions` keyword pattern (spec-level concept) was the right choice — new attributes are additive, not structural.

**Source list is optional and leverages disambiguation.** Rather than requiring `reminders change <title> <source> list <target>` always, the source list is optional when the title is unique. Disambiguation (spec 009) handles the multi-match case transparently. The feature builds on existing infrastructure rather than duplicating it.

## Assumptions

- EventKit allows changing `EKReminder.calendar` and saving in one `store.save(_:commit:)` call. This is consistent with how other attributes are changed.
- List names are stable enough that a case-insensitive exact match is reliable. If a list name contains special characters or is very short (e.g., "a"), the first match in the calendars array is used.
- `parseOptions` keywords are whitespace-delimited. A list named "My Projects" (with a space) would require quoting at the shell level: `reminders change "Title" list "My Projects"`. This is acceptable.
