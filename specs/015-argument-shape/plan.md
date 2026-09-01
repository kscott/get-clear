# Implementation Plan: Suite Argument Shape and Quoting Rule

**Branch**: `015-argument-shape` | **Date**: 2026-08-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/015-argument-shape/spec.md`

## Summary

Introduce one shared command-line argument parser in GetClearKit — pure, tokens-in / typed-struct-out, driven by a per-command **CommandShape** descriptor — and wire the six mutating reminders commands (`add`, `change`, `rename`, `remove`, `done`, `show`) to it. This replaces the reminders tool's join-everything-then-regex-split parser, which silently drops a bare multi-word list name and treats `due` as filler rather than a keyword. `list` becomes a required keyword; `due` / `date` become real keywords with an optional `on` filler and a bare-leading-date form that is mutually exclusive with the keyword form; unknown tokens, missing keyword values, and duplicate keywords all become errors. The rule is written into `design.md` and the constitution suite-wide; the other four tools adopt the parser in Phase 2 (#192–195).

## Technical Context

**Language/Version**: Swift 5.9 (swift-tools-version: 5.9)
**Primary Dependencies**: GetClearKit (new parser lives here); Quick + Nimble (testing)
**Storage**: N/A
**Testing**: Quick + Nimble via `swift test`; the parser and all shape definitions are pure — no store, no permissions
**Target Platform**: macOS 14+
**Project Type**: CLI suite (monorepo) — new pure code in `GetClearKit`, consumers in `RemindersLib`
**Performance Goals**: N/A — parses a handful of argv tokens per invocation
**Constraints**: GetClearKit stays free of framework imports (already does); the parser is a pure function; no new package targets; no new flags
**Scale/Scope**: Phase 1 wires 1 tool / 6 commands; Phase 2 wires 4 more tools. ~1 new source file + 1 new test file in GetClearKit; 1 new shape file + 1 new test file in RemindersLib; 7 RemindersLib files updated; `design.md` + constitution + `ARCHITECTURE.md` updated.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Rule | Status | Notes |
|------|--------|-------|
| Tools handle what they can | ✓ PASS | Parser fails clearly with a named cause; never hands a mangled command through as a silent no-op |
| No flags | ✓ PASS | No flags added; the feature is about positional/keyword structure. Reinforces the rule by making `list` a keyword instead of a fragile bare positional |
| No silent failures | ✓ PASS | This is the feature — FR-005/006/007 turn every malformed command into a stderr error + non-zero exit |
| Stdout / stderr split | ✓ PASS | Argument errors travel the existing `fail()` / thrown-error path to stderr |
| Add and remove ship together | ✓ N/A | No new commands |
| Read-only commands never write | ✓ PASS | `list` / `find` / `what` behavior unchanged; `show` gains stricter parsing but stays read-only |
| The vocabulary is fixed | ✓ PASS | `list` already works as a keyword today; `due` / `date` / `on` are date-introducers, not new verbs. The constitution's vocabulary table governs verbs, not the keyword layer (`priority`, `url`, `note`, `repeat` already live there) |
| Setup is idempotent | ✓ N/A | |
| Internal commands absent from usage() | ✓ N/A | |
| Phoning home requires consent | ✓ N/A | |
| Color has exactly three levels | ✓ N/A | Usage text is rewritten but not recolored |
| GetClearKit first | ✓ PASS | FR-022 — the parser and its types live in GetClearKit; RemindersLib holds only reminders-specific shape definitions |
| Timestamps from the system clock | ✓ N/A | |

**No violations. Complexity Tracking section omitted.**

## Project Structure

### Documentation (this feature)

```text
specs/015-argument-shape/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output — parser API + reminders shapes + doc contract
└── tasks.md             # Phase 2 output (/speckit.tasks — not created here)
```

### Source Code

New files marked **NEW**, deletions **DELETE**, everything else updated.

```text
Sources/GetClearKit/
  CommandArguments.swift        NEW  — CommandShape, Keyword, ParsedCommand, ArgumentError,
                                       parseCommand(_ tokens:[String], shape:CommandShape) throws -> ParsedCommand

Tests/GetClearKitTests/
  CommandArgumentsSpec.swift    NEW  — parser behavior: identifiers, bare date + filler, keyword
                                       order-independence, trailing text, all error cases

reminders-cli/Sources/RemindersLib/
  ReminderCommandShapes.swift   NEW  — one CommandShape per mutating command (add, change,
                                       rename, remove, done, show)
  OptionsParsing.swift          UPDATE — delete parseOptions(String) and splitListAndOptions;
                                         add parseOptions(from: ParsedCommand) -> ParsedOptions;
                                         ParsedOptions kept as the domain DTO
  AddHandler.swift              UPDATE — parse via shape; list only from the `list` keyword
  ChangeHandler.swift           UPDATE — parse via shape
  RenameHandler.swift           UPDATE — two identifiers + `list` keyword (was args[3] positional)
  RemoveHandler.swift           UPDATE — title + `list` keyword (was args[2] positional)
  DoneHandler.swift             UPDATE — title + `list` keyword
  ShowHandler.swift             UPDATE — title + `list` keyword
  ReminderChangeParsing.swift   UPDATE — verify `due none` + other changes both apply (FR-012);
                                         likely no logic change, the fix is upstream in the parser
  UsageText.swift               UPDATE — shared notation, `list <name>`, the three-sentence rule,
                                         the one-line quoting note

reminders-cli/Tests/RemindersLibTests/
  ReminderCommandShapesSpec.swift NEW — each command's shape parses its documented forms and
                                        rejects the malformed ones
  OptionsParsingSpec.swift      UPDATE — rewrite against parseOptions(from:)
  AddHandlerSpec.swift          UPDATE — `list` keyword; unknown-token / dupe-keyword errors
  ChangeHandlerSpec.swift       UPDATE
  ChangeCommandSpec.swift       UPDATE — `priority high due none` applies both (FR-012 / SC-004)
  RenameHandlerSpec.swift       UPDATE
  RemoveHandlerSpec.swift       UPDATE
  DoneHandlerSpec.swift         UPDATE
  ShowHandlerSpec.swift         UPDATE

design.md                       UPDATE — new "## Argument shape" section (FR-014)
.specify/memory/constitution.md UPDATE — new rule entry, consistent with design.md (FR-015)
ARCHITECTURE.md                 UPDATE — decision-log entry for the shared parser
README.md                       UPDATE — fix any reminders example the new parser rejects (SC-006)
PROMPTS.md                      UPDATE — same

Package.swift                   NO CHANGE — GetClearKit ⇄ RemindersLib deps already exist; no new targets
```

**Structure Decision**: The parser is pure library code with no framework needs, so it goes in `GetClearKit` alongside the existing `RangeParser` / `DateParser` / `ArgParsing` precedent. Reminders-specific keyword sets live in `RemindersLib/ReminderCommandShapes.swift`. No new package target — this is additive to two existing ones.

## Scope boundary within Phase 1

**Wired to the shared parser:** `add`, `change`, `rename`, `remove`, `done`, `show` — every mutating command plus `show` (same `title [list]` shape, same wrong-target risk).

**Left on current parsing in Phase 1 (deliberate):** `list`, `find`, `what`. Each has a shape the descriptor does not model yet — `list` has an optional leading *filter* that is not an identifier plus a `by <order>` keyword; `find` is pure rest-of-line; `what` is range parsing (`parseRange`). All three are read-only and cannot cause a silent wrong write. Extending the descriptor to cover them is a follow-up, noted in research.md, not a Phase 1 blocker.

## Implementation Sequence

Dependency order: parser and its tests first, then the reminders shapes, then handlers, then docs.

### Step 1 — GetClearKit: `CommandArguments.swift`

Pure types + one function. See `contracts/command-parser.md` for the full contract.

- `CommandShape` — `identifiers: [String]`, `acceptsBareDate: Bool`, `keywords: [Keyword]`, `trailingTextKeyword: String?`
- `Keyword` — `canonical: String`, `aliases: [String]` (matching is case-insensitive, whole-token)
- `ParsedCommand` — `identifiers: [String]`, `bareDate: String?`, `values: [String: String]` (keyed by canonical), `trailingText: String?`
- `ArgumentError: LocalizedError` — `missingIdentifier(name:)`, `unexpectedTokens([String])`, `unknownKeyword(String)`, `missingValue(keyword:)`, `duplicateKeyword(String)`, `dateGivenTwice`
- `parseCommand(_ tokens: [String], shape: CommandShape) throws -> ParsedCommand`

Algorithm:
1. Take `shape.identifiers.count` leading tokens as identifiers; fewer than required → `missingIdentifier`.
2. Collect tokens up to the first token that matches a keyword or the trailing-text keyword → the **bare region**.
   - `acceptsBareDate` and region non-empty → strip a leading `due` / `date` / `on` filler token, join the rest as `bareDate`.
   - not `acceptsBareDate` and region non-empty → `unexpectedTokens(region)`.  ← catches the old bare positional list
3. Walk `keyword value…` pairs until the trailing-text keyword or end.
   - token is not a known keyword → `unknownKeyword`.
   - keyword with no following value (next token is another keyword, or end) → `missingValue`.
   - keyword already seen → `duplicateKeyword`.
   - value runs to the next keyword / trailing-text keyword / end; multi-token values join with a space.
4. Trailing-text keyword seen → everything after it, joined, is `trailingText`; stop.
5. `bareDate != nil` **and** a `due`/`date` keyword was also supplied → `dateGivenTwice`.

Quotes never reach this function — argv is already tokenized — so a fully-quoted line and a minimally-quoted line produce identical token streams (FR-002).

### Step 2 — GetClearKitTests: `CommandArgumentsSpec.swift`

`describe("parseCommand")` with contexts per behavior. One assertion per `it`.

- identifiers: exact count consumed; too few → `missingIdentifier`
- bare date: bare region becomes `bareDate`; `due` / `date` / `on` prefix stripped; absent when region empty
- keyword values: single and multi-token; order-independent (two permutations → same `ParsedCommand`)
- trailing text: captured to end; a keyword after it is part of the text
- fully-quoted vs minimal: identical result
- errors, one `it` each: `unexpectedTokens`, `unknownKeyword`, `missingValue`, `duplicateKeyword`, `dateGivenTwice`

### Step 3 — RemindersLib: `ReminderCommandShapes.swift`

One `CommandShape` per command. Keyword set carried forward from today: `list`, `priority`, `url`, `repeat` (+ `repeats` / `repeating` / `repeated`), `due` (+ `date`). `note` is the trailing-text keyword.

| Command | identifiers | acceptsBareDate | keywords | trailingText |
|---|---|---|---|---|
| `add` | `["title"]` | yes | list, priority, url, repeat, due | note |
| `change` | `["title"]` | yes | list, priority, url, repeat, due | note |
| `rename` | `["title", "new title"]` | no | list | — |
| `remove` | `["title"]` | no | list | — |
| `done` | `["title"]` | no | list | — |
| `show` | `["title"]` | no | list | — |

See `contracts/reminders-shapes.md`.

### Step 4 — RemindersLibTests: `ReminderCommandShapesSpec.swift`

For each shape: it parses the canonical example from the usage text, it parses a reordered-keyword variant identically, it rejects a bare word where `list` is now required, it rejects a duplicate keyword.

### Step 5 — RemindersLib: `OptionsParsing.swift`

- Delete `parseOptions(_ s: String)` and `splitListAndOptions`.
- Keep `struct ParsedOptions` unchanged (domain DTO the handlers and `parseReminderChanges` already consume).
- Add `parseOptions(from parsed: ParsedCommand) -> ParsedOptions`:
  - `date` ← `parsed.bareDate ?? parsed.values["due"] ?? ""`
  - `recurrence` ← `parsed.values["repeat"] ?? ""`
  - `priority` ← `parsed.values["priority"] ?? ""`
  - `url` ← `parsed.values["url"] ?? ""`
  - `list` ← `parsed.values["list"] ?? ""`
  - `note` ← `parsed.trailingText ?? ""`

The `due none` combined-change bug (FR-012) is fixed here by construction: `due none` now lands in `values["due"]`, so `date == "none"` reaches `parseReminderChanges` alongside whatever else was set.

### Step 6 — RemindersLib: update the six handlers

Each handler builds its shape (from `ReminderCommandShapes`), calls `parseCommand`, converts `ArgumentError` → `ReminderHandlerError` (so `main.swift`'s existing catch is untouched), then proceeds as today.

- `add` / `change`: `title = parsed.identifiers[0]`; `opts = parseOptions(from: parsed)`; rest unchanged. `splitListAndOptions` call removed; list resolved from `opts.list` via the existing `resolvedList`.
- `rename`: `oldTitle = parsed.identifiers[0]`, `newTitle = parsed.identifiers[1]`, list from `parsed.values["list"]`.
- `remove` / `done` / `show`: `title = parsed.identifiers[0]`, list from `parsed.values["list"]`.
- `resolvedList(named:)` unchanged — still throws "List not found" for an unknown list (FR-009 already satisfied by that path).

### Step 7 — RemindersLib: `UsageText.swift`

Rewrite in the shared notation:
- `<name>` for the quoted identifier, `keyword <value>` for keywords, `note …` shown last
- `list` shown as `list <name>`, no bare `[list]`
- the three-sentence rule and the one-line quoting note printed in full (SC-001)

### Step 8 — RemindersLibTests: update the handler + options specs

- `OptionsParsingSpec` — rewrite against `parseOptions(from:)`
- Six handler specs — `list` keyword in every list-bearing example; add `it` cases for unknown-token and duplicate-keyword rejection
- `ChangeCommandSpec` — add the `priority high due none` → both-applied case (SC-004)

### Step 9 — Documentation

- `design.md` — `## Argument shape` section: the rule, the quoting rule, the one trailing-text exception, worked examples (text drafted in `contracts/doc-argument-shape.md`)
- `.specify/memory/constitution.md` — a rule entry mirroring it
- `ARCHITECTURE.md` — decision-log entry: shared command parser in GetClearKit, `CommandShape` descriptor, Phase 1 reminders / Phase 2 the rest
- `README.md`, `PROMPTS.md` — walk every reminders command example; fix any the parser now rejects (SC-006)

### Step 10 — Agent context + build + test

- `.specify/scripts/bash/update-agent-context.sh claude`
- `swift build -c release 2>&1 | tail -20`
- `swift test 2>&1 | tail -30` — 0 failures
- `swiftformat --lint . && swiftlint lint --quiet` — clean (pre-push gate)

## Complexity Tracking

No constitution violations requiring justification.
