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

**Decision**: `CommandShape` with four fields:

```swift
public struct CommandShape {
    public let identifiers: [String]        // names of the leading quoted positionals; [] / ["title"] / ["title", "new title"]
    public let acceptsBareDate: Bool        // is there a bare date slot right after the identifiers?
    public let keywords: [Keyword]          // recognized keywords, order-independent
    public let trailingTextKeyword: String? // e.g. "note" — captures to end of line, must be last
}

public struct Keyword {
    public let canonical: String            // "list", "priority", "due"
    public let aliases: [String]            // ["date"], ["repeats", "repeating", "repeated"]
}
```

**Rationale**: These four axes are exactly what varies across the suite's commands (confirmed by reading all reminders handlers + the calendar/contacts/mail/text usage texts):
- number of leading identifiers: 0 (`find`), 1 (`add`/`change`/`remove`/`done`/`show`, and contacts/mail/text sends), 2 (`rename`)
- a bare date slot: `add` / `change` only
- a keyword set that differs per command
- one optional "rest of line" field: `note` (reminders), `body` (mail), `message` (text)

Everything else — quoting invariance, order-independence, error detection — is uniform and lives in `parseCommand`, not the descriptor.

**`due` / `date` are modeled as an ordinary keyword** (`Keyword(canonical: "due", aliases: ["date"])`), *plus* the parser strips a leading `due` / `date` / `on` filler from the bare-date region. The "date given two ways" error (FR-011) fires when the bare region produced a date **and** the `due` keyword also appears.

**Alternatives considered**:
- *A grammar / parser-combinator* — over-built for "identifier, optional bare date, keyword-value pairs, trailing text". The four-field struct is legible and every tool author can read it.
- *Positional slots beyond the identifier* (e.g. an ordered `[list, date]`) — rejected; the whole feature is about removing fragile positionals. Only the single bare date survives, because "`add "X" march 1`" is how people talk.

---

## R3 — How does the trailing free-text field coexist with token parsing?

**Decision**: `parseCommand` walks the token array left to right. When it reaches a token equal to `trailingTextKeyword`, it stops structured parsing and joins every remaining token with a single space as `trailingText`. Anything after — including words that are keywords elsewhere — is literal text (spec US4 scenario 2).

**Rationale**: This is what the current `parseOptions` already does (it extracts `note`-to-end first, then parses the remainder), so behavior is preserved: `note` may appear anywhere, but everything after it is note text, so in practice it comes last. Quotes on the note are irrelevant to the result (the shell consumed them) but allowed — and are the escape hatch for a literal `$` or `"` (FR-004).

**Edge**: `trailingTextKeyword` also participates in keyword-position scanning for the bare-region boundary — a `note` immediately after the identifier ends the bare region just like any keyword would, then captures the rest.

---

## R4 — Which commands get wired in Phase 1?

**Decision**: `add`, `change`, `rename`, `remove`, `done`, `show`. `list`, `find`, `what` keep their current parsing.

**Rationale**:
- The six are the FR-008 set ("commands that specify a target list") plus `show`, which shares the exact `title [list]` shape and the same resolve-the-wrong-record risk.
- `list` has an optional leading *filter* that is neither an identifier nor a date, plus a `by <order>` keyword — the descriptor does not model an optional non-identifier leading positional, and `list` is read-only so it carries no silent-write risk.
- `find` is pure rest-of-line (`args.dropFirst().joined`). Modeling it needs a "trailing text from position 0, no keyword" mode the descriptor doesn't have.
- `what` is range parsing via `parseRange`, a separate concern.

**Follow-up (not a Phase 1 blocker)**: extend `CommandShape` with an optional leading-filter slot and a "trailing text from start" mode so `list` and `find` can adopt the parser too. Fold into a Phase 2 issue or a small cleanup after #192–195.

---

## R5 — How do argument errors reach the user?

**Decision**: `ArgumentError: LocalizedError` with a case per failure. Reminders handlers catch it and rethrow as `ReminderHandlerError(argError.errorDescription!)`, so `reminders/main.swift`'s existing `catch let e as ReminderHandlerError { fail(e.message) }` path is unchanged.

**Rationale**: Keeps `main.swift` dispatch-only (constitution) and routes every argument error through the one `fail()` sink that already writes to stderr with a non-zero exit (FR-005, SC-003). Phase 2 tools do the same wrap with their own handler-error type.

**Alternatives considered**: `main.swift` catching `ArgumentError` directly — marginally better messages, but spreads error handling across the dispatch switch and each tool's main. The wrap is one line per handler and keeps the pattern uniform.

**Message quality**: each `ArgumentError` case carries the offending token(s) or keyword name, e.g. `unexpectedTokens(["House", "Stuff"])` → `"unexpected: House Stuff — did you mean: list \"House Stuff\"?"`; `unknownKeyword("priorty")` → `"unrecognized: priorty"`; `dateGivenTwice` → `"date given two ways — use a bare date or the due keyword, not both"`.

---

## R6 — Does `parseReminderChanges` need to change for FR-012?

**Decision**: No logic change expected; add a regression test.

**Rationale**: The bug today is upstream — `due` is stripped as filler off the front of the date field, so when another keyword precedes it (`priority high due none`) the date field is empty and `due none` is swallowed into `priority`'s value. With `due` as a real keyword, `values["due"] = "none"` → `parseOptions(from:)` sets `opts.date = "none"` → `parseReminderChanges` already has a `if opts.date.lowercased() == "none" { due = .cleared }` branch that runs independently of the priority branch. FR-012 is fixed by the parser; `parseReminderChanges` just needs `ChangeCommandSpec` proof (SC-004).

---

## R7 — `design.md` section text and the constitution entry

**Decision**: draft text lives in `contracts/doc-argument-shape.md`; the constitution gets a condensed mirror. Both land in Step 9.

**Shape of the `design.md` section** (`## Argument shape`, sits near "Conversational design"):
- the three-sentence rule
- the quoting rule ("quote every name; quoting any value is safe; double quotes; single-quote a literal `"` or `$`")
- the one trailing-free-text exception, stated as deliberate
- worked before/after examples (from the spec's US tables)
- a short "why `list` is a keyword" note tied to the silent-failure it removes

**Constitution entry** (a new `## Argument shape` rule): the one-paragraph version — identifier first, one bare-or-`due` date, keyword-value pairs any order, one trailing free-text field last; unrecognized tokens are errors; the parser is shared and lives in GetClearKit.

---

## R8 — Regression surface: what currently-valid commands change?

From reading the handlers and their specs:

| Today | After | Note |
|---|---|---|
| `reminders add "X" Bills` (Bills exists) | `reminders add "X" list Bills` | bare positional list removed |
| `reminders remove "X" Bills` | `reminders remove "X" list Bills` | `remove`/`done`/`show`/`rename` took a bare `args[N]` list |
| `reminders change "X" priorty high` → silent no-op | error `unrecognized: priorty` | FR-005 |
| `reminders change "X" priority high due none` → clear dropped | both applied | FR-012 |
| `reminders add "X" march 1` | unchanged | bare date kept |
| `reminders add "X" due friday note buy milk` | unchanged | |

Every doc example and every handler spec that uses the bare positional list must be updated in the same change (SC-006, Step 8/9). No external users exist (pre-launch), so this is a hard cut with no transition (spec Decisions).
