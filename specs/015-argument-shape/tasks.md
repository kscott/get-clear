# Tasks: Suite Argument Shape and Quoting Rule

**Input**: Design documents from `/specs/015-argument-shape/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel with other [P] tasks in the same phase (different files, no dependency on an incomplete task)
- **[Story]**: Which user story this task most delivers
- All file paths are relative to the monorepo root

**Tests**: Included — the project mandates a test file per source file (review.md, CLAUDE.md), and lib logic is written interface-first (write the spec, then the code).

---

## Phase 1: Setup

- [ ] T001 Confirm `swift test` is green on the branch tip and note the pass count. No `Package.swift` change is needed — the parser is additive to `GetClearKit`, and `RemindersLib` already depends on `GetClearKit`.

---

## Phase 2: Foundational — the shared parser

**Purpose**: `parseCommand` is the dependency of every downstream task. It implements the mechanisms behind US1 (predictable shape), US3 (`dateGivenTwice`), US4 (trailing text to end), and US6 (all error cases) at the unit level.

**⚠️ CRITICAL**: No command can be wired until this phase is complete.

- [ ] T002 Create `Sources/GetClearKit/CommandArguments.swift` — `Identifier` (name, required), `Keyword` (canonical, aliases), `LeadingRegion` (`.none` | `.bareDate`), `CommandShape` (identifiers, leading, keywords, trailingTextKeyword), `ParsedCommand` (identifiers, bareDate, values, trailingText), `ArgumentError: LocalizedError, Equatable` (the six cases with the messages from `data-model.md`), and `parseCommand(_ tokens: [String], shape: CommandShape) throws -> ParsedCommand` per the algorithm in `contracts/command-parser.md`.
- [ ] T003 Create `Tests/GetClearKitTests/CommandArgumentsSpec.swift` — `describe("parseCommand")`, one assertion per `it`: required/optional/missing identifiers; `.none` rejects a stray token; `.bareDate` strips a leading `due`/`date`/`on`; keyword values single- and multi-token; keyword order-independence (two permutations → equal `ParsedCommand`); trailing text captured to end including later keywords; a fully-quoted token stream ≡ its minimally-quoted equivalent; one `it` per `ArgumentError` case (`missingIdentifier`, `unexpectedTokens`, `unknownKeyword`, `missingValue`, `duplicateKeyword`, `dateGivenTwice`).

**Checkpoint**: `swift test --filter CommandArgumentsSpec` passes.

---

## Phase 3: User Stories 2, 3, 6 — Reminders record commands through the parser (Priority: P1) 🎯 MVP

**Goal**: `add`, `change`, `rename`, `remove`, `done`, `show` parse via the shared parser. `list` is a keyword — no bare positional, no silent drop. A `due none` clear applies alongside other changes. Unknown tokens, missing values, and duplicate keywords error with the token named.

**Independent Test**:
- `reminders remove "Pay rent" list "Household Bills"` removes it from that list.
- `reminders remove "Pay rent" Household Bills` → `unexpected: Household Bills — quote it? remove "Pay rent"` (or the list hint), exit non-zero, nothing removed.
- `reminders change "Pay rent" priority high due none` → priority set **and** due cleared (re-read to confirm).
- `reminders change "Pay rent" priorty high` → `unrecognized: priorty`, no change.

- [ ] T004 [US2] Create `reminders-cli/Sources/RemindersLib/ReminderCommandShapes.swift` — `CommandShape` values for `add`, `change`, `rename`, `remove`, `done`, `show` per the table in `data-model.md` (keywords `list`, `priority`, `url`, `repeat`+aliases, `due`+`date`; `note` as `trailingTextKeyword` on `add`/`change`).
- [ ] T005 [US2] Create `reminders-cli/Tests/RemindersLibTests/ReminderCommandShapesSpec.swift` — per shape: parses its canonical `contracts/reminders-shapes.md` form; a reordered-keyword variant parses identically; a stray word where a quoted name belongs → `unexpectedTokens`; a duplicate keyword → `duplicateKeyword`. Plus one shape-self-validation `it` (unique canonicals; ≤1 optional identifier and it is last; `trailingTextKeyword` not in `keywords`).
- [ ] T006 [US2] Rewrite `reminders-cli/Sources/RemindersLib/OptionsParsing.swift` — delete `parseOptions(_ s: String)` and `splitListAndOptions`; keep `struct ParsedOptions` unchanged; add `parseOptions(from parsed: ParsedCommand) -> ParsedOptions` with the mapping in `data-model.md` (`date` ← `bareDate ?? values["due"] ?? ""`, etc.).
- [ ] T007 [US2] Rewrite `reminders-cli/Tests/RemindersLibTests/OptionsParsingSpec.swift` against `parseOptions(from:)` — bare date, `due` keyword, `due none`, each keyword, `note` from `trailingText`, empty fields.
- [ ] T008 [US2] Update `reminders-cli/Sources/RemindersLib/AddHandler.swift` — `parsed = try parseCommand(Array(args.dropFirst()), shape: ReminderCommandShapes.add)` wrapped in `catch let e as ArgumentError { throw ReminderHandlerError(e.errorDescription ?? "invalid arguments") }`; `title = parsed.identifiers[0]`; `opts = parseOptions(from: parsed)`; delete the `splitListAndOptions` call; list resolved from `opts.list` via the existing `resolvedList`.
- [ ] T009 [US3] Update `reminders-cli/Sources/RemindersLib/ChangeHandler.swift` — same pattern with `ReminderCommandShapes.change`; `opts = parseOptions(from: parsed)` carries `date == "none"` from the `due` keyword regardless of other keywords present.
- [ ] T010 [P] [US2] Update `reminders-cli/Sources/RemindersLib/RenameHandler.swift` — `ReminderCommandShapes.rename`; `oldTitle = parsed.identifiers[0]`, `newTitle = parsed.identifiers[1]`, list from `parsed.values["list"]` (was the bare `args[3]`).
- [ ] T011 [P] [US2] Update `reminders-cli/Sources/RemindersLib/RemoveHandler.swift` — `ReminderCommandShapes.remove`; `title = parsed.identifiers[0]`, list from `parsed.values["list"]` (was the bare `args[2]`).
- [ ] T012 [P] [US2] Update `reminders-cli/Sources/RemindersLib/DoneHandler.swift` — `ReminderCommandShapes.done`, same pattern.
- [ ] T013 [P] [US2] Update `reminders-cli/Sources/RemindersLib/ShowHandler.swift` — `ReminderCommandShapes.show`, same pattern.
- [ ] T014 [US3] Update `reminders-cli/Sources/RemindersLib/ReminderChangeParsing.swift` — verify the existing `if opts.date.lowercased() == "none" { due = .cleared }` branch runs independently of the priority/recurrence/url branches. No logic change expected; add a one-line comment noting `due none` now arrives via the `due` keyword.
- [ ] T015 [P] [US6] Update `reminders-cli/Tests/RemindersLibTests/AddHandlerSpec.swift` — `list` keyword in every list-bearing example; add `it`s: `unknownKeyword`, `missingValue`, `duplicateKeyword`, and a stray-token case each surface as `ReminderHandlerError` with the offending token in `.message`.
- [ ] T016 [P] [US6] Update `reminders-cli/Tests/RemindersLibTests/ChangeHandlerSpec.swift` — same shape of updates for `change`.
- [ ] T017 [P] [US3] Update `reminders-cli/Tests/RemindersLibTests/ChangeCommandSpec.swift` — `reminders change "X" priority high due none` → both `priority` and `due cleared` in the result (SC-004); `reminders change "X" march 1 due none` → `dateGivenTwice` surfaced as `ReminderHandlerError`.
- [ ] T018 [P] [US6] Update `reminders-cli/Tests/RemindersLibTests/RenameHandlerSpec.swift` — `list` keyword; a bare `args[3]`-style list token → error.
- [ ] T019 [P] [US6] Update `reminders-cli/Tests/RemindersLibTests/RemoveHandlerSpec.swift` — `list` keyword; stray token → error; `reminders remove` alone → `missingIdentifier`.
- [ ] T020 [P] [US6] Update `reminders-cli/Tests/RemindersLibTests/DoneHandlerSpec.swift` — same.
- [ ] T021 [P] [US6] Update `reminders-cli/Tests/RemindersLibTests/ShowHandlerSpec.swift` — same.

**Checkpoint**: `swift test --filter RemindersLibTests` passes; a manual `swift run reminders-bin remove "…" list "…"` behaves per the Independent Test.

---

## Phase 4: User Story 1 — every command, one rule (Priority: P1)

**Goal**: `list` and `find` also parse via the shared parser, so all eight argument-taking commands obey the same rule. `reminders list by <bad>` errors instead of silently sorting by due.

**Independent Test**: Form ten varied commands from the three-sentence rule (multi-word names, reordered keywords, `due` in different positions, a trailing note) — all parse as intended (SC-002). `reminders list "Household Bills" by priority` filters and sorts; `reminders list by sideways` → error. `reminders find "pick up milk"` searches; `reminders find pick up milk` → quote hint.

- [ ] T022 [US1] Add `list` and `find` `CommandShape` values to `reminders-cli/Sources/RemindersLib/ReminderCommandShapes.swift` — `list`: `identifiers [Identifier("list", required: false)]`, keywords `[Keyword("by")]`; `find`: `identifiers [Identifier("query")]`, no keywords.
- [ ] T023 [US1] Extend `reminders-cli/Tests/RemindersLibTests/ReminderCommandShapesSpec.swift` — `list`: bare (no filter), quoted filter, `by` value, filter + `by`, stray extra token → error; `find`: quoted query, `reminders find` alone → `missingIdentifier(name: "query")`, multi-word unquoted → `unexpectedTokens`.
- [ ] T024 [US1] Update `reminders-cli/Sources/RemindersLib/ListHandler.swift` — parse via `ReminderCommandShapes.list`; `filterName = parsed.identifiers.first`; map `parsed.values["by"]` to `ReminderSortOrder`, throwing `ReminderHandlerError("unknown sort: <value>")` on an unrecognized value (replaces the current `?? .due` silent fallback); drop the manual `by` index-scanning.
- [ ] T025 [US1] Update `reminders-cli/Sources/RemindersLib/FindHandler.swift` — parse via `ReminderCommandShapes.find`; `query = parsed.identifiers[0]`; remove the local `guard args.count > 1` check (the parser now throws `missingIdentifier`).
- [ ] T026 [P] [US1] Update `reminders-cli/Tests/RemindersLibTests/ListHandlerSpec.swift` — filter as a one-token identifier; `by` order-independent of the filter; unknown sort → error; existing grouping/sorting assertions unchanged.
- [ ] T027 [P] [US1] Update `reminders-cli/Tests/RemindersLibTests/FindHandlerSpec.swift` — quoted multi-word query; `reminders find` alone → error; multi-word unquoted → error.

**Checkpoint**: all eight commands route through `parseCommand`; the SC-002 ten-command check passes.

---

## Phase 5: User Stories 5, 4 — documentation (Priority: P2)

**Goal**: the rule is written into `design.md` and the constitution; the reminders usage text and every shipped example teach the shared shape, with all space-containing values quoted (note/query included).

**Independent Test**: read the reminders `--help` output and `design.md` `## Argument shape` — a person can form any reminders command from them alone. No example in the repo is rejected by the parser (SC-006).

- [ ] T028 [US5] Add the `## Argument shape` section to `design.md` (after "Conversational design") using the draft in `contracts/doc-argument-shape.md` — the three-sentence rule, the quoting rule, the trailing-text exception stated as deliberate, worked examples (every space-containing value quoted, `note` included), the "why `list` is a keyword" note.
- [ ] T029 [P] [US5] Add the `## Argument shape` rule to `.specify/memory/constitution.md` — the condensed mirror from `contracts/doc-argument-shape.md`, consistent with `design.md`.
- [ ] T030 [P] [US5] Add a decision-log entry to `ARCHITECTURE.md` — shared command parser in GetClearKit (`CommandArguments.swift`), the `CommandShape` descriptor, Phase 1 = reminders / Phase 2 = #192–195, and the deferred `lists`/`open` guard.
- [ ] T031 [US5] Rewrite `reminders-cli/Sources/RemindersLib/UsageText.swift` — shared notation (`<name>`, `keyword <value>`, `note "…"` last), `list "<name>"` (no bare `[list]`), the three-sentence rule and the one-line quoting note printed in full (SC-001), every example value with a space quoted.
- [ ] T032 [P] [US4] Create `reminders-cli/Tests/RemindersLibTests/UsageTextSpec.swift` — assert the usage text contains the three-sentence rule and the quoting note, shows `list <name>`, contains no bare `[list]` positional, and shows `note` quoted in its example.
- [ ] T033 [US5] Sweep `README.md` and `PROMPTS.md` for every `reminders add|change|rename|remove|done|show|list|find` example — fix any form the parser now rejects, add the `list` keyword, quote note/query content (checklist in `contracts/doc-argument-shape.md`). Leave `what` / `lists` / `open` examples alone.

---

## Phase 6: Polish & Validation

- [ ] T034 Run `.specify/scripts/bash/update-agent-context.sh claude`; keep the added line in house style.
- [ ] T035 Run `swift build -c release` — zero errors, zero new warnings.
- [ ] T036 Run `swift test` — all pass; report the total count. Spot-check the success criteria: SC-002 (ten varied commands), SC-004 (`priority high due none` applies both), SC-005 (a fully-quoted usage example ≡ its minimal form), SC-006 (extract every fenced `reminders` command from `design.md`/`README.md`/`PROMPTS.md`/`UsageText.swift` and confirm none is rejected).
- [ ] T037 Run `swiftformat --lint . && swiftlint lint --quiet` — clean (pre-push gate).

---

## Dependencies

```
T001
 └─ T002 ─ T003                         (parser + spec — Phase 2)
     └─ T004 ─ T005                     (record shapes + spec)
         └─ T006 ─ T007                 (OptionsParsing + spec)
             ├─ T008 (add)  ─ T015 [P]  T017 [P]
             ├─ T009 (change) ─ T014 ─ T016 [P]
             ├─ T010 [P] (rename) ─ T018 [P]
             ├─ T011 [P] (remove) ─ T019 [P]
             ├─ T012 [P] (done)   ─ T020 [P]
             └─ T013 [P] (show)   ─ T021 [P]
                 └─ T022 ─ T023            (list + find shapes — Phase 4)
                     ├─ T024 (list) ─ T026 [P]
                     └─ T025 (find) ─ T027 [P]
                         └─ T028 … T033    (docs — Phase 5, T029/T030/T032 [P])
                             └─ T034 ─ T035 ─ T036 ─ T037   (Phase 6)
```

## Parallel Execution Examples

**Phase 3 — the four simple handlers** (after T006):
```
T010  RenameHandler.swift
T011  RemoveHandler.swift
T012  DoneHandler.swift
T013  ShowHandler.swift
```

**Phase 3 — handler spec updates** (each after its source file):
```
T015, T016, T017, T018, T019, T020, T021   (all different test files)
```

**Phase 5 — docs** (after T027):
```
T029  constitution.md
T030  ARCHITECTURE.md
T032  UsageTextSpec.swift        (after T031)
```

## Implementation Strategy

- **MVP = Phases 1–3.** The parser exists and is fully specced; the six record commands go through it. `list` is a keyword, the silent-drop is gone, and `due none` combines correctly. `list`/`find` still use their old parsing but nothing is broken.
- **Phase 4** completes the "one rule, every command" story — the last two commands and the sort-value tightening.
- **Phase 5** is the documentation that makes the rule usable and consistent, and is a hard requirement of the spec (FR-014–017, SC-001, SC-006).
- **Phase 6** validates against the measurable outcomes and the pre-push gate.
- No `main.swift` change anywhere — every handler keeps its `(args:, store:)` signature and still throws `ReminderHandlerError`, so dispatch stays dispatch-only.
- Phase 2 (`CommandArguments.swift` + spec) ships in one commit. Each subsequent source + its spec ship together (review.md).
