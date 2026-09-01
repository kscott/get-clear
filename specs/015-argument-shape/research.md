# Phase 0 Research — Suite Argument Shape

All open questions from the spec checklist, resolved.

---

## R1 — Where does the parser live, and what is its dependency shape?

**Decision**: `Sources/GetClearKit/CommandArguments.swift`. Pure Swift, Foundation only, no framework imports.

**Rationale**: Constitution "GetClearKit first" — the parser is suite infrastructure with no tool-specific knowledge. GetClearKit already holds the parsing precedent: `ArgParsing.swift` (command dispatch), `RangeParser.swift` (`parseRange` → `ParsedRange`), `DateParser.swift` (`parseDate` → `ParsedDate`). Each is a pure `String(s) -> typed struct?` (or `throws`) function with a Quick spec. `parseCommand` follows the identical mould, one level up: it consumes the token array `ArgParsing` already produced and hands back a typed `ParsedCommand`.

**Alternatives considered**:
- *Per-tool parsers* — rejected by FR-022 and by the Phase 2 issues, which are only cheap if the parser is shared.
- *A new package target* — unjustified; GetClearKit is exactly the right home and a new target adds graph complexity for one file.

---

## R2 — What does the per-command descriptor look like?

**Decision**: `CommandShape` with four fields; see `contracts/command-parser.md` and `data-model.md` for the exact types.

```swift
public struct CommandShape {
    public let identifiers: [Identifier]    // one-token positionals; Identifier has a name + required flag
    public let leading: LeadingRegion       // .none | .bareDate — what the pre-keyword tokens mean
    public let keywords: [Keyword]          // recognized keywords, order-independent
    public let trailingTextKeyword: String? // "note" — captures to end of line
}
```

**The design took four iterations with Ken:**

1. Flat struct with `identifiers: [String]` + `acceptsBareDate: Bool`.
2. `reminders list "Household Bills"` → `list` needs an **optional** identifier → `Identifier` gained a `required` flag.
3. Tried a `.subject` / `.freeText` leading mode for `find`/`what` so multi-word queries wouldn't need quotes.
4. Ken rejected that — "identifier is one token, add quotes otherwise" — as the same over-flexibility he'd rejected for `remove`. `find`'s query is a plain required identifier: `reminders find "pick up milk"`. `.freeText` deleted. `LeadingRegion` is now just `.none | .bareDate`.

**The one rule Ken locked**: every identifier is exactly one token, quoted if it has a space — including a search query. No "greedy up to the first keyword." A stray token is `unexpectedTokens` with a "quote it?" hint. The single value that never needs quoting is the trailing text field (`note` / `body` / `message`) — the exception Ken blessed explicitly ("never needs, but allows, quotes").

**`due` / `date`** are an ordinary keyword (`Keyword("due", aliases: ["date"])`). `dateGivenTwice` (FR-011) fires when the bare region produced a date **and** the `due` keyword also appeared. *(Post-analyze: the `on` filler is not handled by the argument parser at all — see refinements below.)*

**Alternatives considered**:
- *A grammar / parser-combinator* — over-built for "identifiers, optional bare date, keyword-value pairs, trailing text". The struct is legible; every tool author reads it at a glance.
- *A free-text leading mode* — see iteration 3–4 above. Rejected. Keeping `find`'s query as a quoted identifier means one rule with no carve-outs but the trailing field.

---

## R3 — How does the trailing free-text field coexist with token parsing?

**Decision**: `parseCommand` walks the token array left to right. When it reaches a token equal to `trailingTextKeyword`, it stops structured parsing and joins every remaining token with a single space as `trailingText`. Anything after — including words that are keywords elsewhere — is literal text (spec US4 scenario 2).

**Rationale**: This is what the current `parseOptions` already does (it extracts `note`-to-end first, then parses the remainder), so behavior is preserved: `note` may appear anywhere, but everything after it is note text, so in practice it comes last. Quotes on the note are irrelevant to the result (the shell consumed them) but allowed — and are the escape hatch for a literal `$` or `"` (FR-004).

**Edge**: `trailingTextKeyword` also participates in keyword-position scanning for the bare-region boundary — a `note` immediately after the identifier ends the bare region just like any keyword would, then captures the rest.

---

## R4 — Which commands get wired in Phase 1?

**Decision (locked with Ken)**: `add`, `change`, `rename`, `remove`, `done`, `show`, `list`, `find` — every reminders command that takes an argument the user could get wrong. `what`, `lists`, `open` do not get a shape.

**The line**: a command goes through `parseCommand` if it names a record and/or carries keywords — i.e. if there is argument structure to validate and a silent-failure path today. That is the eight above.

- `add` / `change` — 1 identifier, bare date, keywords, `note` tail
- `rename` — 2 identifiers, `list` keyword
- `remove` / `done` / `show` — 1 identifier, `list` keyword
- `list` — 1 **optional** identifier (the filter), `by` keyword
- `find` — 1 required identifier (the query, quoted if multi-word), no keywords

**`what` is excluded** — its argument handling (`parseRange` on a range string) is being lifted into `GetClearKit.runWhatCommand` by #40, out of RemindersLib, and #197 questions whether tool-level `what` should exist at all. Spec 015 leaves it alone; whichever of #40 / #197 lands decides its parsing.

**`lists` / `open` are excluded** — they take no arguments, and their handlers don't receive the args array (`.open` dispatches before the command switch). A stray-token guard needs plumbing outside this feature's scope — deferred. Extra tokens are ignored today (harmless — not a silent *wrong* action).

This is not a partial migration — it is every command the parser is *for*.

---

## R5 — How do argument errors reach the user?

**Decision**: `ArgumentError: LocalizedError` with a case per failure. Reminders handlers catch it and rethrow as `ReminderHandlerError(argError.errorDescription!)`, so `reminders/main.swift`'s existing `catch let e as ReminderHandlerError { fail(e.message) }` path is unchanged.

**Rationale**: Keeps `main.swift` dispatch-only (constitution) and routes every argument error through the one `fail()` sink that already writes to stderr with a non-zero exit (FR-005, SC-003). Phase 2 tools do the same wrap with their own handler-error type.

**Alternatives considered**: `main.swift` catching `ArgumentError` directly — marginally better messages, but spreads error handling across the dispatch switch and each tool's main. The wrap is one line per handler and keeps the pattern uniform.

**Message quality**: each `ArgumentError` case carries the offending token(s) or keyword name, e.g. `unexpectedTokens(["House", "Stuff"])` → `"unexpected: House Stuff — did you mean: list \"House Stuff\"?"`; `unknownKeyword("priorty")` → `"unrecognized: priorty"`; `dateGivenTwice` → `"date given two ways — use a bare date or the due keyword, not both"`.

---

## R6 — Does `parseReminderChanges` need to change for FR-012?

**Decision**: No logic change expected; add a regression test.

**Rationale**: The bug today is upstream — `due` is stripped as filler off the front of the date field, so when another keyword precedes it (`priority high due none`) the date field is empty and `due none` is swallowed into `priority`'s value. With `due` as a real keyword, `values["due"] = "none"` → `parseOptions(from:)` sets `opts.date = "none"` → `parseReminderChanges` already has a `if opts.date.lowercased() == "none" { due = .cleared }` branch that runs independently of the priority branch. FR-012 is fixed by the parser; `parseReminderChanges` needs `ChangeCommandSpec` proof (SC-004) *and* the FR-024 change (reject an unknown priority instead of swallowing it — see refinements below).

---

## R7 — `design.md` section text and the constitution entry

**Decision**: draft text is in `contracts/doc-argument-shape.md`; the constitution gets a condensed mirror. Both land in Step 8.

**`design.md` section** (`## Argument shape`, near "Conversational design"): the three-sentence rule; the quoting rule (quote every name; quoting any value is safe; double quotes; single-quote a literal `"` or `$`; the trailing free-text field never needs quotes); the trailing-text exception stated as deliberate; worked before/after examples; a "why `list` is a keyword" note tied to the silent failure it removes.

**Constitution entry** (`## Argument shape`): one paragraph — identifier first (one token, quoted if spaced), one bare-or-`due` date not both, keyword-value pairs any order, one trailing free-text field last; unrecognized tokens are errors; the shared parser lives in GetClearKit.

---

## R8 — Regression surface: what currently-valid commands change?

From reading every handler and its spec:

| Today | After | Note |
|---|---|---|
| `reminders add "X" Bills` (Bills exists) | `reminders add "X" list Bills` | bare positional list removed (add/change) |
| `reminders remove "X" Bills` | `reminders remove "X" list Bills` | `remove`/`done`/`show` took a bare `args[2]` list; `rename` a bare `args[3]` |
| `reminders list Bills` | `reminders list "Bills"` (works) / `reminders list Household Bills` → error | filter is a one-token identifier now |
| `reminders list by garbage` → sorts by due | error `unknown sort: garbage` | `handleList` validates the `by` value (was a silent fallback) |
| `reminders find pick up milk` | `reminders find "pick up milk"` | query is a one-token identifier — multi-word must be quoted |
| `reminders find` → "provide a search query" | `missingIdentifier(name: "query")` | same effect, now from the parser |
| `reminders change "X" priorty high` → silent no-op | error `unrecognized: priorty` | FR-005 |
| `reminders change "X" priority high due none` → clear dropped | both applied | FR-012 |
| `reminders open junk` / `reminders lists junk` → ignored | still ignored | guard deferred (harmless) |
| `reminders add "X" march 1` | unchanged | bare date kept |
| `reminders what …` | unchanged | not touched by 015 |

Every doc example and every handler spec using a now-rejected form is updated in the same change (SC-006, Steps 8–9). Pre-launch, so hard cut, no transition (spec Decisions).

---

## Post-analyze refinements (2026-09-01)

`/speckit.analyze` (second pass) plus review with Ken settled four points the planning pass left loose:

1. **`reminders add list` is an error, not a reminder titled "list".** The keyword check applies to *every* identifier, required or optional — a bare unquoted keyword word is never consumed as a name. `missingIdentifier` names the token and says to quote it. The spec edge case that said otherwise was the defect. Quoting forces it: `reminders add "list"`.
2. **The `on` filler moves into `DateParser`.** `GetClearKit/DateParser.swift` strips a leading `on` exactly as it already strips a leading `at` before a time. `due on friday` (a `due` keyword whose value is `"on friday"`), `on march 1` (bare), and `march 1` (bare) then resolve identically with zero argument-parser special-casing. FR-013 reworded accordingly.
3. **FR-024 — a bad value errors, it is not swallowed.** `parsePriority` returning nil, an unknown `by` sort key, and an unparseable date on the `add` path currently drop silently or default. All three now throw an error naming the value, matching how recurrence already behaves. Live "no silent failures" holes, closed here.
4. **Scope is all eight argument-taking commands** (`add`, `change`, `rename`, `remove`, `done`, `show`, `list`, `find`) — the spec body was tightened from its `add`/`change`-centric wording to match the plan's locked scope. "No half-assed migration" (Ken).
