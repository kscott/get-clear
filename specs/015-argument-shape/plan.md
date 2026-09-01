# Implementation Plan: Suite Argument Shape and Quoting Rule

**Branch**: `015-argument-shape` | **Date**: 2026-08-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/015-argument-shape/spec.md`

## Summary

Introduce one shared command-line argument parser in GetClearKit — pure, tokens-in / typed-struct-out, driven by a per-command **CommandShape** descriptor — and wire **eight** reminders commands to it: `add`, `change`, `rename`, `remove`, `done`, `show`, `list`, `find` (every command that takes an argument the user could get wrong). This replaces the reminders tool's join-everything-then-regex-split parser, which silently drops a bare multi-word list name and treats `due` as filler rather than a keyword. `list` becomes a keyword; every identifier becomes exactly one token (quoted if spaced); `due` / `date` become real keywords with an optional `on` filler and a bare-leading-date form mutually exclusive with the keyword form; unknown tokens, missing keyword values, duplicate keywords, and a stray token where a quoted name belongs all become errors. `lists` / `open` get a one-line no-argument guard. `what` is untouched (leaving RemindersLib via #40; existence questioned by #197). The rule is written into `design.md` and the constitution suite-wide; the other four tools adopt the parser in Phase 2 (#192–195).

## Technical Context

**Language/Version**: Swift 5.9 (swift-tools-version: 5.9)
**Primary Dependencies**: GetClearKit (new parser lives here); Quick + Nimble (testing)
**Storage**: N/A
**Testing**: Quick + Nimble via `swift test`; the parser and all shape definitions are pure — no store, no permissions
**Target Platform**: macOS 14+
**Project Type**: CLI suite (monorepo) — new pure code in `GetClearKit`, consumers in `RemindersLib`
**Performance Goals**: N/A — parses a handful of argv tokens per invocation
**Constraints**: GetClearKit stays free of framework imports; the parser is a pure function; no new package targets; no new flags
**Scale/Scope**: Phase 1 wires 1 tool / 8 commands; Phase 2 wires 4 more tools. 1 new source + 1 new test file in GetClearKit; 1 new shape + 1 new test file in RemindersLib; ~9 RemindersLib files updated; `design.md` + constitution + `ARCHITECTURE.md` updated.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design — still passes; the design added no targets, no flags, no framework imports, and routes every error to stderr.*

| Rule | Status | Notes |
|------|--------|-------|
| Tools handle what they can | ✓ PASS | Parser fails clearly with a named cause; never passes a mangled command through as a silent no-op |
| No flags | ✓ PASS | None added; the feature is about positional/keyword structure. `list` becomes a keyword instead of a fragile bare positional |
| No silent failures | ✓ PASS | This is the feature — FR-005/006/007 turn every malformed command into a stderr error + non-zero exit |
| Stdout / stderr split | ✓ PASS | Argument errors travel the existing thrown-error → `fail()` path to stderr |
| Add and remove ship together | ✓ N/A | No new commands |
| Read-only commands never write | ✓ PASS | `list` / `find` gain stricter parsing but stay read-only; `what` untouched |
| The vocabulary is fixed | ✓ PASS | `list` already works as a keyword today; `due` / `date` / `on` / `by` are not new verbs. The vocabulary table governs verbs; the keyword layer (`priority`, `url`, `note`, `repeat`) is separate and established |
| Setup is idempotent | ✓ N/A | |
| Internal commands absent from usage() | ✓ N/A | |
| Phoning home requires consent | ✓ N/A | |
| Color has exactly three levels | ✓ N/A | Usage text rewritten, not recolored |
| GetClearKit first | ✓ PASS | FR-022 — parser + types in GetClearKit; RemindersLib holds only reminders shape definitions |
| Timestamps from the system clock | ✓ N/A | |

**No violations. Complexity Tracking omitted.**

## Project Structure

### Documentation (this feature)

```text
specs/015-argument-shape/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # command-parser.md, reminders-shapes.md, doc-argument-shape.md
└── tasks.md             # Phase 2 output (/speckit.tasks — not created here)
```

### Source Code

New files **NEW**, deletions **DELETE**, everything else updated.

```text
Sources/GetClearKit/
  CommandArguments.swift          NEW  — Identifier, Keyword, LeadingRegion, CommandShape,
                                         ParsedCommand, ArgumentError,
                                         parseCommand(_ tokens:[String], shape:CommandShape) throws -> ParsedCommand

Tests/GetClearKitTests/
  CommandArgumentsSpec.swift      NEW  — identifiers (required/optional), each LeadingRegion,
                                         keyword order-independence, trailing text, quoting invariance,
                                         every ArgumentError case

reminders-cli/Sources/RemindersLib/
  ReminderCommandShapes.swift     NEW  — a CommandShape for add, change, rename, remove, done,
                                         show, list, find
  OptionsParsing.swift            UPDATE — delete parseOptions(String) + splitListAndOptions;
                                           add parseOptions(from: ParsedCommand) -> ParsedOptions;
                                           ParsedOptions kept as the domain DTO
  AddHandler.swift                UPDATE — parse via shape; list from the `list` keyword only
  ChangeHandler.swift             UPDATE — parse via shape
  RenameHandler.swift             UPDATE — two identifiers + `list` keyword (was args[3])
  RemoveHandler.swift             UPDATE — title + `list` keyword (was args[2])
  DoneHandler.swift               UPDATE — title + `list` keyword
  ShowHandler.swift               UPDATE — title + `list` keyword
  ListHandler.swift               UPDATE — filter from optional identifier; `by` keyword;
                                           reject an unknown sort value (was a silent fallback)
  FindHandler.swift               UPDATE — query from `parsed.freeText`
  ReminderChangeParsing.swift     UPDATE — verify only; `due none` + other changes both apply (FR-012),
                                           fixed upstream by the `due` keyword
  UsageText.swift                 UPDATE — shared notation; `list <name>`; three-sentence rule; quoting note

reminders-cli/Tests/RemindersLibTests/
  ReminderCommandShapesSpec.swift NEW  — each shape parses its documented forms, rejects the malformed
  OptionsParsingSpec.swift        UPDATE — rewrite against parseOptions(from:)
  AddHandlerSpec.swift            UPDATE — `list` keyword; unknown-token / dupe-keyword errors
  ChangeHandlerSpec.swift         UPDATE
  ChangeCommandSpec.swift         UPDATE — `priority high due none` applies both (FR-012 / SC-004)
  RenameHandlerSpec.swift         UPDATE
  RemoveHandlerSpec.swift         UPDATE
  DoneHandlerSpec.swift           UPDATE
  ShowHandlerSpec.swift           UPDATE
  ListHandlerSpec.swift           UPDATE — filter as identifier; unknown-sort error
  FindHandlerSpec.swift           UPDATE — freeText query; empty → "provide a search query"

design.md                         UPDATE — new "## Argument shape" section (FR-014)
.specify/memory/constitution.md   UPDATE — new rule entry (FR-015)
ARCHITECTURE.md                   UPDATE — decision-log entry for the shared parser
README.md, PROMPTS.md             UPDATE — fix any reminders example the parser now rejects (SC-006)

Package.swift                     NO CHANGE — GetClearKit ⇄ RemindersLib deps exist; no new targets
```

**Structure Decision**: pure library code with no framework needs → `GetClearKit`, beside the `RangeParser` / `DateParser` / `ArgParsing` precedent. Reminders keyword sets → `RemindersLib/ReminderCommandShapes.swift`. No new package target — additive to two existing ones.

## Scope — locked with Ken

**Through `parseCommand` (8):** `add`, `change`, `rename`, `remove`, `done`, `show`, `list`, `find`. The line: a command goes through the parser if it names a record and/or carries keywords — i.e. there is structure to validate and a silent-failure path today.

**Not given a shape:**
- `what` — its arg handling is being lifted into `GetClearKit.runWhatCommand` by #40, and #197 questions whether tool-level `what` should exist. Untouched here.
- `lists` / `open` — take no arguments. Their handlers (`handleLists(store:)`, `handleOpen(opener:)`) don't currently receive the args array, and `.open` is dispatched before the command switch. Rejecting `reminders open junk` would need args plumbed into those handlers or a nullary check in `runCLI` — deferred as a small follow-up. Current behavior (extra tokens ignored) is harmless; this is not a silent *wrong* action.

This is every command the parser is *for*. `find` (in every tool) makes `LeadingRegion.freeText` a real suite-wide mode, not a one-command curiosity.

## Implementation Sequence

Dependency order: parser + tests, then shapes, then handlers, then docs.

### Step 1 — GetClearKit: `CommandArguments.swift`

Pure types + one function. Full contract in `contracts/command-parser.md`; types in `data-model.md`. Algorithm:

1. **Identifiers** — for each `Identifier` in order: consume one token if the next token exists and is not a keyword; required + unavailable → `missingIdentifier(name:)`; optional + unavailable → skip.
2. **Leading region** — collect tokens up to the first keyword (or `trailingTextKeyword`):
   - `.none` + non-empty → `unexpectedTokens` (with a "quote it?" hint when the command names a record). Catches `remove "X" Bills`, `list Household Bills`, `open junk`.
   - `.bareDate` + non-empty → strip a leading `due`/`date`/`on`, join → `bareDate`.
   - `.freeText` + non-empty → join → `freeText`.
3. **Keyword pairs** to `trailingTextKeyword` / end: unknown → `unknownKeyword`; no value → `missingValue`; repeat canonical → `duplicateKeyword`; value = tokens to next keyword / trailing-text / end.
4. `trailingTextKeyword` → rest joined → `trailingText`; stop.
5. `bareDate != nil` **and** `due`/`date` keyword seen → `dateGivenTwice`.

Quotes never reach this function (argv is tokenized) → fully-quoted ≡ minimally-quoted (FR-002).

### Step 2 — GetClearKitTests: `CommandArgumentsSpec.swift`

`describe("parseCommand")`, one assertion per `it`: required vs optional identifiers; each `LeadingRegion` (`.none` rejects, `.bareDate` strips filler, `.freeText` joins); keyword order-independence (two permutations → equal `ParsedCommand`); trailing text captured to end incl. later keywords; fully-quoted ≡ minimal; one `it` per `ArgumentError` case.

### Step 3 — RemindersLib: `ReminderCommandShapes.swift`

Eight `CommandShape` values. Table in `data-model.md`; accepted/rejected forms in `contracts/reminders-shapes.md`.

### Step 4 — RemindersLibTests: `ReminderCommandShapesSpec.swift`

Per shape: parses its canonical usage-text example; parses a reordered-keyword variant identically; rejects a bare word where a quoted name belongs; rejects a duplicate keyword. Plus a shape-self-validation spec (unique canonicals, ≤1 optional identifier last, `.freeText` not with `trailingTextKeyword`).

### Step 5 — RemindersLib: `OptionsParsing.swift`

Delete `parseOptions(_ s: String)` and `splitListAndOptions`. Keep `struct ParsedOptions`. Add `parseOptions(from: ParsedCommand) -> ParsedOptions` mapping per `data-model.md`. FR-012 fixed by construction: `due none` → `values["due"]` → `date == "none"` reaches `parseReminderChanges` regardless of other keywords.

### Step 6 — RemindersLib: update the eight handlers

Each: build its shape, call `parseCommand(Array(args.dropFirst()), shape:)`, `catch ArgumentError → ReminderHandlerError`, proceed as today.

- `add` / `change`: `title = parsed.identifiers[0]`; `opts = parseOptions(from: parsed)`.
- `rename`: `identifiers[0]`, `identifiers[1]`, list from `values["list"]`.
- `remove` / `done` / `show`: `identifiers[0]`, list from `values["list"]`.
- `list`: `filter = parsed.identifiers.first`; `order` from `values["by"]` — `handleList` throws on an unknown sort instead of falling back to `.due`.
- `find`: `query = parsed.freeText`; `nil` → existing "provide a search query".
- `lists` / `open`: add the no-argument guard.
- `resolvedList(named:)` unchanged — still throws "List not found" (FR-009).

### Step 7 — RemindersLib: `UsageText.swift`

Shared notation: `<name>` quoted identifier, `keyword <value>`, `note …` last, `list <name>` (no bare `[list]`), the three-sentence rule and the one-line quoting note in full (SC-001). Decide whether `what` gets a usage line (currently absent) — default: leave absent, it's mid-move per #40/#197.

### Step 8 — Documentation + specs

- `design.md` `## Argument shape`, `.specify/memory/constitution.md` rule entry — text drafted in `contracts/doc-argument-shape.md`.
- `ARCHITECTURE.md` decision-log entry: shared parser in GetClearKit, `CommandShape` descriptor, Phase 1 reminders / Phase 2 #192–195.
- `README.md`, `PROMPTS.md`, `UsageText.swift` — every reminders `add|change|rename|remove|done|show|list|find` example checked against the parser; stale ones fixed (SC-006). `list`/`find` examples now in scope; `what` examples left alone.
- Update the reminders handler specs (Step 6's files) for the `list` keyword and the new error cases; `ChangeCommandSpec` gets the FR-012 case.

### Step 9 — Agent context + build + test

- `.specify/scripts/bash/update-agent-context.sh claude`
- `swift build -c release 2>&1 | tail -20`
- `swift test 2>&1 | tail -30` — 0 failures
- `swiftformat --lint . && swiftlint lint --quiet` — clean (pre-push gate)

## Complexity Tracking

No constitution violations requiring justification.
