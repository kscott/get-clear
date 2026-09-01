# Feature Specification: Suite Argument Shape and Quoting Rule

**Feature Branch**: `015-argument-shape`
**Created**: 2026-08-31
**Status**: Draft
**Input**: User description: "Define one argument-shape rule for the whole suite, document it in design.md and the constitution, and bring the tools into line. Today there is no stated rule about when a value must be quoted or where it goes on the line; the reminders tool in particular is loose — a bare multi-word list name is silently dropped, and `due` is not a real keyword so a due-clear combined with another change is lost. Most of the suite already follows a consistent shape; this feature names it, writes it down, and fixes the outliers. Lands before the location-alarm (#191) and private-metadata (#014) vocabulary work so both build on a stated rule."

---

## Background

Get Clear commands read as plain English: `reminders add "Pay rent" march 1 repeat monthly`, `contacts change Bob phone 555-1234`. But there is no written rule for how a command line is shaped — specifically:

1. **When does a value need quoting, and why?** The examples in `design.md` use quotes, but no document states a rule. The one mention anywhere is an aside in spec 011: a spaced list name "would require quoting at the shell level… This is acceptable."
2. **Where does each value go on the line?** Which values are bare positionals, which are introduced by a keyword, and in what order.

The result is drift. Four tools land in roughly the same place by convention; the reminders tool is the outlier and has two concrete defects:

- **A bare multi-word list name is silently dropped.** `reminders add "Pay rent" "House Stuff" march 1` — when "House Stuff" is not already an existing list — treats `House Stuff march 1` as the due date, fails to parse it, and creates the reminder with no due date in the default list. No error. This violates the constitution's "no silent failures."
- **`due` is not a real keyword.** It is a filler word stripped from the front of the date field. So `reminders change "Pay rent" priority high due none` silently drops the due-clear: `due none` is swallowed into the priority value, `priority` fails to parse, and nothing happens.

This feature does not invent a new interaction style. It names the shape the suite already mostly follows, records it in `design.md` and the constitution, and brings the reminders tool fully into line — a proper strict parser, not a patch on the current regex split. It is sequenced before #191 (location-alarm vocabulary) and #014 (private-metadata vocabulary) so both add keywords onto a stated rule instead of compounding the drift.

**This is Phase 1.** It covers the rule, the two suite documents, and the reminders tool. Bringing calendar, contacts, mail, and text to the same strict shape is Phase 2 — a separate feature, tracked by a per-tool migration issue each. Those four tools already follow the shape loosely; Phase 1 does not touch their parsers or usage text beyond what the rule's ratification in `design.md` implies.

---

## User Scenarios & Testing *(mandatory)*

The actors are the **person** typing commands at a terminal and **Claude** constructing command lines on the person's behalf. The rule must serve both: a person forming a command from the reference card alone, and Claude producing lines that would read naturally if the person had typed them.

### User Story 1 — One rule predicts every command (Priority: P1)

A person reads a short rule (three sentences) and, from that alone, can correctly form any add/change command in the reminders tool — including where multi-word values go and whether they need quoting. The rule is written to generalize to all five tools (Phase 2), but Phase 1 proves it on reminders.

**Why this priority**: This is the whole point. The value is a single mental model that transfers across the suite, so the person never has to remember per-tool argument order.

**Independent Test**: Give someone the three-sentence rule and the command list from `--help`. Ask them to write ten commands covering multi-word names, lists, dates, multiple keywords, and a trailing note. Every command they write parses correctly.

**Acceptance Scenarios**:

1. **Given** the rule and the reminders usage text, **When** a person writes `reminders add "Pay rent" due "march 1" list "House Stuff" priority high`, **Then** it creates the reminder with that due date, in that list, at that priority.
2. **Given** the rule, **When** a person wraps every argument in quotes (`reminders add "Pay rent" "march 1" "list" "Bills"`), **Then** it parses identically to the minimally-quoted form.
3. **Given** the rule, **When** a person writes a command with the keywords in a different order (`reminders change "Pay rent" list Bills priority high due friday`), **Then** it parses identically regardless of keyword order.

---

### User Story 2 — List assignment is explicit and never silently dropped (Priority: P1)

To put a reminder in a list, the person names the list with the `list` keyword. There is no bare positional list. A multi-word list name is quoted like any other multi-word value. A list that does not exist produces an error, not a silent fallback to the default list.

**Why this priority**: This removes the current silent-failure vector and the confusing "works only if the list already exists" behavior. It is the single most common source of "I fought with getting the order right."

**Independent Test**: Run `reminders add "X" list "House Stuff" friday` where "House Stuff" exists (reminder lands there) and where it does not (error naming the unknown list, no reminder created in the wrong place).

**Acceptance Scenarios**:

1. **Given** a list "House Stuff" exists, **When** the person runs `reminders add "Pay rent" list "House Stuff" march 1`, **Then** the reminder is created in "House Stuff" with that due date.
2. **Given** no list named "House Stuff", **When** the person runs `reminders add "Pay rent" list "House Stuff"`, **Then** the tool fails with a message naming the unknown list and creates nothing.
3. **Given** any input, **When** a bare word appears where a list used to be accepted positionally (`reminders add "Pay rent" Bills march 1`), **Then** "Bills march 1" is interpreted as the date, fails to parse as a date, and the tool errors — it does not silently create a dateless reminder.

---

### User Story 3 — The date is bare or `due`-introduced, never both (Priority: P1)

The due date can be given as a bare value right after the name, or introduced anywhere on the line by the `due` (or `date`) keyword. `due` is a real keyword: it works after other keywords, and `due none` clears the date even when combined with other changes. Giving the date both ways in one command is an error.

**Why this priority**: Fixes the `change … priority high due none` defect and makes the date field behave like every other field while keeping the natural bare form.

**Independent Test**: Run `reminders change "X" priority high due none` (both the priority change and the due-clear take effect), `reminders add "X" due friday` and `reminders add "X" friday` (identical result), and `reminders change "X" march 1 due none` (error — date given two ways).

**Acceptance Scenarios**:

1. **Given** a reminder with a due date and a priority, **When** the person runs `reminders change "Pay rent" priority high due none`, **Then** the priority is set to high AND the due date is cleared.
2. **Given** any reminder, **When** the person runs `reminders add "Pay rent" due friday` or `reminders add "Pay rent" friday`, **Then** both produce the same reminder due Friday.
3. **Given** any reminder, **When** the person runs `reminders change "Pay rent" march 1 due none`, **Then** the tool fails with "date given two ways" and makes no change.
4. **Given** a bare leading date, **When** the person prefixes it with `due` or `date` (`reminders add "X" date "next friday"`), **Then** the prefix is accepted and stripped.

---

### User Story 4 — The trailing free-text field is last, and quoting is optional (Priority: P2)

`note` (reminders), `body` (mail), and `message` (text) capture everything after the keyword to the end of the line. They come last. They never need quotes — but quotes are allowed and harmless, and are the way to include a literal `$` or `"` that the shell would otherwise mangle. **Documentation and usage-text examples quote the trailing field anyway**, so a reader sees one pattern: quote every value.

**Why this priority**: This is the one documented exception to "every value is `keyword value`," and it needs to be stated clearly so people know it is deliberate, not an inconsistency — while the examples still model the quote-everything habit.

**Independent Test**: Run `reminders add "Call dentist" friday note ask about the crown` (note captured, no quotes), `reminders add "Call dentist" note "ask about the crown"` (identical), and confirm no keyword after `note` is interpreted as a keyword.

**Acceptance Scenarios**:

1. **Given** the command `reminders add "Call dentist" friday note ask about the crown`, **When** it runs, **Then** the note is "ask about the crown" and the due date is Friday.
2. **Given** the command `reminders add "X" note "buy milk" priority high`, **When** it runs, **Then** the note is `buy milk priority high` — everything after `note` is note text, including words that are keywords elsewhere.
3. **Given** a note that needs a literal dollar sign, **When** the person single-quotes that argument, **Then** the literal text is preserved.

---

### User Story 5 — Every tool teaches the same shape (Priority: P2)

Each tool's `--help` / usage output presents its commands in the shared shape: `<name>` for the quoted identifier, keywords shown as `keyword <value>`, the trailing free-text field shown last, and a one-line quoting note. A person who learns one tool's help can read all five.

**Why this priority**: The rule is only as good as its visibility. If the usage texts still show `[list]` as a bare positional, the drift persists in the docs even after the code is fixed.

**Independent Test**: Read all five usage texts side by side. The notation is consistent; no tool shows a bare positional except `<name>` and an optional date; each carries the same quoting one-liner.

**Acceptance Scenarios**:

1. **Given** the reminders usage text, **When** a person reads it, **Then** `list` is shown as `list <name>`, not as a bare `[list]` positional.
2. **Given** any tool's usage text, **When** a person reads it, **Then** it states the quoting rule in one line.
3. **Given** all five usage texts, **When** compared, **Then** the same notation conventions are used throughout.

---

### User Story 6 — Unrecognized tokens are an error, not silent input (Priority: P2)

A token that is not the name, a date, a recognized keyword, or a keyword's value produces an error naming the token. A misspelled keyword (`priorty high`) does not silently become part of the date.

**Why this priority**: "No silent failures" applied to argument parsing. A typo in a keyword should tell the person, not quietly do the wrong thing.

**Independent Test**: Run `reminders change "X" priorty high` and confirm an error naming `priorty`, with no change made.

**Acceptance Scenarios**:

1. **Given** the command `reminders change "Pay rent" priorty high`, **When** it runs, **Then** the tool fails with a message naming `priorty` as unrecognized and makes no change.
2. **Given** a keyword with no value (`reminders change "Pay rent" priority`), **When** it runs, **Then** the tool fails stating `priority` needs a value.
3. **Given** a keyword given twice (`reminders change "Pay rent" priority high priority low`), **When** it runs, **Then** the tool fails rather than silently applying one.

---

### Edge Cases

- **A value contains a double quote or a dollar sign**: the docs direct the person to single-quote that argument. The tool itself sees the resolved token and does nothing special.
- **The name is a single word that happens to be a keyword** (`reminders add list`): the name is always position 1 and is never scanned for keywords, so this creates a reminder titled "list".
- **A keyword value is empty because the person quoted an empty string** (`priority ""`): treated as a missing value → error, same as US6 scenario 2.
- **Claude constructs the line**: Claude uses the tools through Claude Code skills that shell out to the CLI, so Claude builds the command line and is bound by this rule exactly as a person is — quote any value with a space, never rely on bare multi-word positionals. There is no structured-parameter path that bypasses it (the former MCP server was removed in favor of skills — spec 009). The skill guidance should state the rule.
- **`due none` given with no other changes**: clears the date (existing behavior, preserved).
- **An existing command in current documentation examples**: if the shape change would break a documented example, the example is updated in the same change — no example in any shipped doc may show a form the parser rejects.

---

## Requirements *(mandatory)*

### Functional Requirements — The rule

- **FR-001**: The suite MUST adopt a single argument shape: (1) one identifier in position 1, quoted by the person if it contains spaces; (2) one due date, given either bare immediately after the identifier or introduced anywhere by the `due` / `date` keyword, but not both; (3) every other value introduced by a keyword, in any order; (4) one optional trailing free-text field that captures to end of line and comes last.
- **FR-002**: Wrapping any value in quotes MUST be safe — a fully-quoted command line MUST parse identically to the minimally-quoted equivalent. (Quotes are resolved by the shell; the tool only ever sees tokens.)
- **FR-003**: Keyword order MUST NOT affect parsing. Any permutation of `keyword value` pairs MUST produce the same result.
- **FR-004**: The documented default quote style MUST be double quotes. The docs MUST carry a one-line note that a value containing a literal `"` or `$` should be single-quoted.
- **FR-005**: A token that is not the identifier, a date, a recognized keyword, or a keyword's value MUST produce an error naming the token. It MUST NOT be silently absorbed into another field.
- **FR-006**: A keyword given with no following value MUST produce an error stating the keyword needs a value.
- **FR-007**: A keyword given more than once in a single command MUST produce an error.

### Functional Requirements — Reminders changes

- **FR-008**: The reminders tool MUST require the `list` keyword to specify a target list. The bare positional list (and the "consume the first argument only if it matches an existing list" behavior) MUST be removed.
- **FR-009**: Specifying a list that does not exist MUST produce an error naming the unknown list and MUST NOT fall back to the default list.
- **FR-010**: `due` and `date` MUST be recognized keywords that can appear anywhere in the command, with the same effect as a bare leading date. `due none` MUST clear the due date regardless of position and regardless of other changes in the same command.
- **FR-011**: A command that specifies the date both as a bare leading value and via the `due` / `date` keyword MUST produce a "date given two ways" error and make no change.
- **FR-012**: `reminders change` MUST apply a `due none` clear together with any other field changes in the same command. (Fixes the current defect where `priority high due none` drops the clear.)
- **FR-013**: The date introducer accepts an optional trailing `on`: `due`, `date`, `due on`, `date on`, and a bare leading `on` all introduce a date value (`add "X" due on friday`, `add "X" on march 1`). The filler word is stripped before date parsing. A bare leading date with no introducer is still valid (`add "X" march 1`).

### Functional Requirements — Documentation

- **FR-014**: `design.md` MUST gain a section stating the argument shape rule, the quoting rule, and the single trailing-free-text exception, with worked examples. This is written suite-wide, not reminders-only.
- **FR-015**: The suite constitution MUST gain a rule entry for the argument shape, consistent with `design.md` (per the constitution's own "when this document conflicts with design.md, update both").
- **FR-016**: The reminders `--help` / usage output MUST present its commands in the shared notation: `<name>` for the quoted identifier, `keyword <value>` for keyword-introduced values, the trailing free-text field last, and the one-line quoting note. `list` MUST be shown as `list <name>`, not a bare `[list]` positional. Every example value that could contain a space — including the trailing free-text field — MUST be shown quoted.
- **FR-017**: No example in a shipped document that shows a **reminders** command (`design.md`, `README.md`, `PROMPTS.md`, the reminders usage text) may show an argument form the reminders parser rejects after this change. Examples for the other four tools are addressed in their Phase 2 issues.

### Functional Requirements — Scope

- **FR-018**: Phase 1 changes the **reminders** tool's parser and usage text only. Calendar, contacts, mail, and text are not modified in this feature.
- **FR-019**: A migration issue is filed for each of calendar (#192), contacts (#193), mail (#194), and text (#195): audit the parser against FR-001..FR-013, apply the strictness requirements (FR-005..FR-007), bring the usage text into the shared notation, fix stale doc examples. Phase 2.
- **FR-020**: The `--draft` flag in mail is a separate known violation tracked elsewhere and is out of scope.
- **FR-021**: The parser MUST be built as a proper argument parser (tokens → typed fields with explicit validation), not as additional passes over the current join-and-regex-split. "If we are going to be strict, support it explicitly and properly."
- **FR-022**: The parser MUST live in GetClearKit and be tool-agnostic, driven by a per-tool command-shape descriptor. Phase 1 wires reminders to it; Phase 2 (#192–195) wires the other four. The reminders handlers and `RemindersLib` consume typed fields from it, not raw token strings.

### Key Entities

- **Identifier**: The primary field a record is found and referred to by — a reminder's title, a contact's name, a message recipient. Always position 1. Quoted if it contains spaces. Never scanned for keywords.
- **Bare date**: An optional due date given immediately after the identifier. The one permitted bare positional besides the identifier. May carry an optional `due` / `date` / `on` filler prefix. Distinct from the `due` keyword (FR-010), which can appear anywhere.
- **Keyword**: A recognized word that introduces exactly one following value (which may itself be multi-word, running to the next keyword or the trailing free-text field). Order-independent.
- **Trailing free-text field**: `note` / `body` / `message`. Captures everything after the keyword to end of line. Comes last. Never needs quotes; allows them.
- **Argument shape**: The composition of a command line from the four element types above. Defined suite-wide in `design.md` and the constitution; enforced in the reminders parser in Phase 1, in the other four tools in Phase 2.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The argument shape rule fits in three sentences and is printed in full in the reminders usage text and in `design.md`.
- **SC-002**: From the three-sentence rule plus the command list, a person forms ten varied reminders commands (multi-word names, lists, reordered keywords, `due` in different positions, trailing note) and 100% parse as intended.
- **SC-003**: Zero silent failures in reminders argument parsing: every malformed command (unknown token, missing keyword value, unknown list, date given twice, duplicate keyword) produces a stderr message and a non-zero exit.
- **SC-004**: `reminders change "X" priority high due none` applies both changes — verified by re-reading the reminder.
- **SC-005**: A fully-quoted reminders command line and its minimally-quoted equivalent produce byte-identical output for every command in the reminders usage examples.
- **SC-006**: Someone reviews every reminders command shown as an example anywhere in the repo docs (`design.md`, `README.md`, `PROMPTS.md`, the usage text) and confirms each one is still valid under the new rule — no example teaches a form the parser now rejects.

---

## Decisions locked (2026-08-31, with Ken)

- **List keyword: `list` only.** No `in`, no `to`, no `in list`. `in` collides with relative-date phrasing ("in 3 days"); `list` matches the `list` / `lists` commands and never appears in a date.
- **Keep the bare leading date** (`add "X" march 1`). The date-as-required-keyword option was rejected.
- **Scope split:** Phase 1 (this feature) = the rule + `design.md` + constitution + the reminders parser and usage text, built properly. Phase 2 = calendar, contacts, mail, text, one migration issue each.
- **Hard cut.** No transitional acceptance of the old bare-list form. It errors immediately. Get Clear is pre-launch; there is no deprecation debt worth carrying.
- **`due` / `date` both accepted**, plus an optional `on` filler.
- **The parser lives in GetClearKit.** It is built tool-agnostic — parameterized by a per-tool command-shape descriptor (its keyword set, which field is the trailing free-text one, whether it has a bare-date slot) — because all five tools will share it (Phase 1 reminders, Phase 2 the rest). Consistent with the constitution's "GetClearKit first."

## Assumptions

- The reminders parser is rebuilt as a real tokens-to-fields parser (FR-021), not patched. This is expected to touch `OptionsParsing.swift`, `ReminderChangeParsing.swift`, `AddHandler`, `ChangeHandler`, and their specs, and may relocate logic to a shared home per "GetClearKit first."
- The bare leading date stays because `add "Pay rent" march 1` is how people speak and the date parser is well-bounded.
- `list` gaining a mandatory keyword is a net simplification: one extra word in the common case buys the removal of the silent-failure path and the name-dependent behavior.
- The other four tools follow the shape loosely today; Phase 1 leaves their code and usage text untouched. The `design.md` / constitution text is written suite-wide so Phase 2 is "conform to the written rule," not "invent it."
- Claude uses the tools through Claude Code skills that shell out to the CLI (the MCP server was removed in favor of skills — spec 009). Claude constructs command lines and follows this rule like any caller; the reminders skill guidance should carry it.

## Out of Scope

- Calendar, contacts, mail, text parser or usage-text changes — Phase 2, one issue each (FR-019).
- The `--draft` flag violation in mail (tracked separately).
- Any new command or new keyword. This feature defines the shape; #191 and #014 add vocabulary within it.
- Changing identifier-resolution or fuzzy-matching behavior. Only the *shape* of the line and the *quoting* rule are in scope.
- Localization of keywords.
