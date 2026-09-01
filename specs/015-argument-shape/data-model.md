# Phase 1 Data Model — Suite Argument Shape

Pure value types in `GetClearKit` (`CommandArguments.swift`). `CommandShape` **instances** are per-tool (`RemindersLib/ReminderCommandShapes.swift` in Phase 1).

---

## The naming rule (drives the whole model)

- **An identifier is exactly one token.** It names a specific record (a reminder title, a list name, a new title). If it contains a space, it is quoted. There is no "greedy up to the first keyword" — a stray extra token is an error that tells the user to quote.
- **Free text is the rest of the tail.** It is a search query or a date range — not a name. No quotes required. Only `find` and `what` have it.
- **The trailing text field** (`note` / `body` / `message`) is also the rest of the tail, but it starts after its keyword. No quotes required.

---

## Identifier

```swift
public struct Identifier: Sendable, Equatable {
    public let name: String        // for error messages: "title", "new title", "list"
    public let required: Bool
    public init(_ name: String, required: Bool = true)
}
```

At most one identifier may be `required: false`, and it must be last in the array. `list` is the only reminders command with an optional identifier.

---

## LeadingRegion

The meaning of any tokens between the identifiers and the first keyword.

```swift
public enum LeadingRegion: Sendable, Equatable {
    case none                 // nothing permitted here — a token is an error
    case bareDate             // add / change — optional date, `due`/`date`/`on` filler stripped, guards "date given two ways"
    case freeText(String)     // find / what — the rest of the tail (multi-token, no quotes); the String names it
}
```

A shape with an optional identifier must use `leading: .none` (cannot combine an optional name with a bare date or free text).

---

## CommandShape

| Field | Type | Meaning |
|---|---|---|
| `identifiers` | `[Identifier]` | Leading one-token positionals, in order. |
| `leading` | `LeadingRegion` | What the pre-keyword region means. |
| `keywords` | `[Keyword]` | Recognized keywords; order-independent everywhere. |
| `trailingTextKeyword` | `String?` | Keyword that captures the rest of the line as literal text and ends parsing (`note` on `add`/`change`). |

**Shape self-validation (tested):** `trailingTextKeyword` not also in `keywords`; each `Keyword.canonical` unique vs all canonicals and aliases; at most one non-required identifier, last; `.freeText` not combined with `trailingTextKeyword`.

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
| `bareDate` | `String?` | `.bareDate` region minus a leading `due`/`date`/`on`; `nil` if empty or not a `.bareDate` shape. |
| `freeText` | `String?` | `.freeText` region, space-joined; `nil` if empty or not a `.freeText` shape. |
| `values` | `[String: String]` | One entry per keyword that appeared, keyed by canonical, space-joined value. |
| `trailingText` | `String?` | Everything after `trailingTextKeyword`; `nil` if that keyword did not appear. |

**Guarantees:** fully-quoted ≡ minimally-quoted (FR-002); keyword order irrelevant (FR-003).

---

## ArgumentError

| Case | Fires when | Message |
|---|---|---|
| `missingIdentifier(name:)` | a required identifier has no token (end, or next token is a keyword) | `provide a <name>` |
| `unexpectedTokens([String])` | tokens in a `.none` leading region (i.e. after the identifiers there is a non-keyword token) | `unexpected: <tokens>` — with `— quote it? <command> "<full name>"` hint when the command names a record |
| `unknownKeyword(String)` | a token where a keyword is expected matches no canonical/alias | `unrecognized: <token>` |
| `missingValue(keyword:)` | a keyword is last, or immediately followed by another keyword | `<keyword> needs a value` |
| `duplicateKeyword(String)` | same keyword (by canonical) twice | `<keyword> given twice` |
| `dateGivenTwice` | `bareDate` produced **and** the `due`/`date` keyword also appeared | `date given two ways — use a bare date or due, not both` |

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
add    identifiers [req "title"]                  leading .bareDate          keywords [list, priority, url, repeat, due]  trailing "note"
change identifiers [req "title"]                  leading .bareDate          keywords [list, priority, url, repeat, due]  trailing "note"
rename identifiers [req "title", req "new title"] leading .none              keywords [list]                             trailing nil
remove identifiers [req "title"]                  leading .none              keywords [list]                             trailing nil
done   identifiers [req "title"]                  leading .none              keywords [list]                             trailing nil
show   identifiers [req "title"]                  leading .none              keywords [list]                             trailing nil
list   identifiers [opt "list"]                   leading .none              keywords [by]                               trailing nil
find   identifiers []                             leading .freeText("query") keywords []                                 trailing nil
```

Keywords: `list` / `priority` / `url` no aliases; `repeat` → `repeats`/`repeating`/`repeated`; `due` → `date`; `by` no aliases (value `due`/`priority`/`title`/`created`, validated by `handleList`); `note` is the trailing-text keyword on `add`/`change`.

## Commands NOT given a shape

- **`what`** — its argument handling is being lifted into `GetClearKit.runWhatCommand(args:tool:)` by #40, out of RemindersLib; #197 questions tool-level `what` entirely. Spec 015 does not touch it.
- **`lists`, `open`** — take no arguments. `handleLists(store:)` / `handleOpen(opener:)` don't receive the args array and `.open` dispatches before the command switch, so a stray-token guard needs plumbing not in this feature's scope — deferred as a small follow-up. Extra tokens are ignored today (harmless — not a silent *wrong* action).

## Handler consumption

- `list` — `filter = parsed.identifiers.first`; `order` from `parsed.values["by"]`; `handleList` rejects an unknown sort (tightening — was a silent fallback to `.due`)
- `find` — `query = parsed.freeText`; empty (`freeText == nil`) → `handleFind` throws `"provide a search query"` (unchanged)
