# Phase 1 Data Model — Suite Argument Shape

Pure value types in `GetClearKit` (`CommandArguments.swift`). `CommandShape` **instances** are per-tool (`RemindersLib/ReminderCommandShapes.swift` in Phase 1).

---

## The one rule

Every identifier — a title, a new title, a list name, a search query — is **exactly one token**, quoted if it contains a space. No "greedy up to the first keyword." A stray extra token is an error that tells the user to quote. A bare unquoted keyword word is never taken as an identifier — `reminders add list` errors; `reminders add "list"` works. The **only** value that never needs quoting is the trailing text field (`note` / `body` / `message`), which captures the rest of the line — the single exception, blessed explicitly.

---

## Identifier

```swift
public struct Identifier: Sendable, Equatable {
    public let name: String        // for error messages: "title", "new title", "list", "query"
    public let required: Bool
    public init(_ name: String, required: Bool = true)
}
```

At most one identifier may be `required: false`, and it must be last. In reminders, only `list` has one (its optional filter).

---

## LeadingRegion

The meaning of any tokens between the identifiers and the first keyword.

```swift
public enum LeadingRegion: Sendable, Equatable {
    case none        // nothing permitted — a token is an error
    case bareDate    // add / change — optional date, captured verbatim; guards "date given two ways"
}
```

The `.bareDate` region is passed through untouched. `due` / `date` are keywords (they never land here); a leading `on` (`add "X" on march 1`) is left for the shared date parser, which strips it like the existing `at` before a time.

Only `add` and `change` use `.bareDate`. Everything else is `.none`.

---

## CommandShape

| Field | Type | Meaning |
|---|---|---|
| `identifiers` | `[Identifier]` | Leading one-token positionals, in order. |
| `leading` | `LeadingRegion` | `.none` or `.bareDate`. |
| `keywords` | `[Keyword]` | Recognized keywords; order-independent everywhere. |
| `trailingTextKeyword` | `String?` | Keyword that captures the rest of the line as literal text and ends parsing (`note` on `add`/`change`). |

**Shape self-validation (tested):** `trailingTextKeyword` not also in `keywords`; each `Keyword.canonical` unique vs all canonicals and aliases; at most one non-required identifier, last.

---

## Keyword

```swift
public struct Keyword: Sendable, Equatable {
    public let canonical: String
    public let aliases: [String]
    public init(_ canonical: String, aliases: [String] = [])
}
```

Case-insensitive, whole-token matching.

---

## ParsedCommand

| Field | Type | Meaning |
|---|---|---|
| `identifiers` | `[String]` | One entry per identifier that was present (so `list` yields 0 or 1). |
| `bareDate` | `String?` | `.bareDate` region joined verbatim; `nil` if empty or not a `.bareDate` shape. |
| `values` | `[String: String]` | One entry per keyword that appeared, keyed by canonical, space-joined value. |
| `trailingText` | `String?` | Everything after `trailingTextKeyword`; `nil` if that keyword did not appear. |

**Guarantees:** fully-quoted ≡ minimally-quoted (FR-002); keyword order irrelevant (FR-003).

---

## ArgumentError

`enum ArgumentError: Error, LocalizedError, Equatable`.

| Case | Fires when | Message |
|---|---|---|
| `missingIdentifier(name:)` | a required identifier has no token at end of input | `provide a <name>` |
| `missingIdentifier(name:)` | a required identifier is blocked by a keyword word (`add list`) | `provide a <name> — "<token>" is a keyword; quote it ("<token>") to use it as the <name>` |
| `unexpectedTokens([String])` | tokens in a `.none` leading region — i.e. after the identifiers a non-keyword token appears | `unexpected: <tokens> — if that is part of the <name>, quote it as one argument; otherwise introduce it with a keyword` |
| `unknownKeyword(String)` | a token where a keyword is expected matches no canonical/alias | `unrecognized: <token>` |
| `missingValue(keyword:)` | a keyword is last, or immediately followed by another keyword | `<keyword> needs a value` |
| `duplicateKeyword(String)` | same keyword (by canonical) twice | `<keyword> given twice` |
| `dateGivenTwice` | `bareDate` produced **and** the `due`/`date` keyword also appeared | `date given two ways — use a bare date or due, not both` |

The `unexpectedTokens` and keyword-blocked `missingIdentifier` messages are the generic forms the tool-agnostic parser produces from the shape alone (it knows the identifier name and the keyword set). It does not guess which keyword the stray tokens belong to.

Reminders handlers wrap: `catch let e as ArgumentError { throw ReminderHandlerError(e.errorDescription ?? "invalid arguments") }`.

---

## ParsedOptions (unchanged, RemindersLib) — `add` / `change` only

Kept as the domain DTO. Only its producer changes.

| Field | Source |
|---|---|
| `date` | `parsed.bareDate ?? parsed.values["due"] ?? ""` |
| `recurrence` | `parsed.values["repeat"] ?? ""` |
| `priority` | `parsed.values["priority"] ?? ""` |
| `url` | `parsed.values["url"] ?? ""` |
| `list` | `parsed.values["list"] ?? ""` |
| `note` | `parsed.trailingText ?? ""` |

`splitListAndOptions` and `parseOptions(_ s: String)` deleted.

---

## Reminders CommandShape instances — 8 commands through `parseCommand`

```
add    identifiers [req "title"]                  leading .bareDate   keywords [list, priority, url, repeat, due]  trailing "note"
change identifiers [req "title"]                  leading .bareDate   keywords [list, priority, url, repeat, due]  trailing "note"
rename identifiers [req "title", req "new title"] leading .none       keywords [list]                             trailing nil
remove identifiers [req "title"]                  leading .none       keywords [list]                             trailing nil
done   identifiers [req "title"]                  leading .none       keywords [list]                             trailing nil
show   identifiers [req "title"]                  leading .none       keywords [list]                             trailing nil
list   identifiers [opt "list"]                   leading .none       keywords [by]                               trailing nil
find   identifiers [req "query"]                  leading .none       keywords []                                 trailing nil
```

Keywords: `list` / `priority` / `url` no aliases; `repeat` → `repeats`/`repeating`/`repeated`; `due` → `date`; `by` no aliases (value `due`/`priority`/`title`/`created`, validated by `handleList`); `note` is the trailing-text keyword on `add`/`change`.

## Commands NOT given a shape

- **`what`** — its argument handling is being lifted into `GetClearKit.runWhatCommand` by #40, out of RemindersLib; #197 questions tool-level `what` entirely. Spec 015 does not touch it.
- **`lists`, `open`** — take no arguments. `handleLists(store:)` / `handleOpen(opener:)` don't receive the args array and `.open` dispatches before the command switch, so a stray-token guard needs plumbing not in this feature's scope — deferred to **#201**. Extra tokens are ignored today (harmless — not a silent *wrong* action).

## Handler consumption

- `list` — `filter = parsed.identifiers.first`; `order` from `parsed.values["by"]`; `handleList` rejects an unknown sort value with an error naming it (FR-024 — was a silent fallback to `.due`)
- `find` — `query = parsed.identifiers[0]` (required, so always present); `reminders find` → `missingIdentifier(name: "query")` (replaces the current handler-level `"provide a search query"` check)
- `add` / `change` — reject an unrecognized `priority` value with an error naming it (FR-024 — `parsePriority` currently returns `nil` and the change is silently skipped). `change`: `parseReminderChanges` throws **`ReminderChangeError.unrecognizedPriority(String)`** (new case, mirrors `.unrecognizedRecurrence(String)`), which `handleChange` catches → `ReminderHandlerError("unknown priority: <value>")` alongside its existing `.unrecognizedRecurrence` catch. `add`: the handler does its own `parsePriority` check and throws `ReminderHandlerError("unknown priority: <value>")` directly. An unparseable bare/`due` **date** on `add` or `change` errors the same way — `ReminderHandlerError("couldn't parse date: <value>")` — instead of a silent dateless create / no-op. Recurrence already errors this way.

## Shared date parser — the `on` filler (FR-013)

`GetClearKit/DateParser.swift` gains a **new leading-`on` strip at the top of `parseDate`** (after the lowercase/trim on line ~40): a token equal to `on` at the very start of the string is dropped before any pattern matching. (`at` is *not* a leading strip today — it is tolerated inside the time-pattern regex; `on` is a leading-position filler and needs its own small addition, ~2 lines.) Result: `parseDate("on march 1") == parseDate("march 1")`, `parseDate("on friday") == parseDate("friday")`. This is the whole of the `on` handling — the argument parser passes date strings through untouched, so `due on friday` (keyword value `"on friday"`), `on march 1` (bare), and `march 1` (bare) all resolve identically.
