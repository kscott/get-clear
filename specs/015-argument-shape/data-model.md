# Phase 1 Data Model — Suite Argument Shape

All types are pure value types in `GetClearKit` (`CommandArguments.swift`), except `CommandShape` instances, which are defined per-tool (`RemindersLib/ReminderCommandShapes.swift` in Phase 1).

---

## CommandShape

Describes the argument layout of one command. Static data — one instance per command, no state.

| Field | Type | Meaning |
|---|---|---|
| `identifiers` | `[String]` | Names of the leading quoted positionals, in order. `[]` (no identifier), `["title"]`, `["title", "new title"]`. The names are for error messages only. |
| `acceptsBareDate` | `Bool` | Whether a bare date value may appear immediately after the identifiers (before any keyword). |
| `keywords` | `[Keyword]` | Recognized keywords. Order in the array is irrelevant; order in the command line is irrelevant. |
| `trailingTextKeyword` | `String?` | The keyword that captures the rest of the line as literal text and ends structured parsing. `nil` if the command has no free-text tail. |

**Validation rules**
- `trailingTextKeyword`, when non-nil, must not also appear in `keywords` (it is handled specially).
- A `Keyword`'s `canonical` must be unique across `keywords` and distinct from every alias.

---

## Keyword

| Field | Type | Meaning |
|---|---|---|
| `canonical` | `String` | The keyword's canonical form. `ParsedCommand.values` is keyed by this. |
| `aliases` | `[String]` | Accepted alternate spellings. `due` → `["date"]`; `repeat` → `["repeats", "repeating", "repeated"]`. |

Matching is case-insensitive and whole-token (`priority` matches the token `priority`, never a substring).

---

## ParsedCommand

The parser's output. Consumed by handlers, which then apply domain meaning.

| Field | Type | Meaning |
|---|---|---|
| `identifiers` | `[String]` | Exactly `shape.identifiers.count` entries, in order. |
| `bareDate` | `String?` | The bare date region with any leading `due` / `date` / `on` filler removed, tokens space-joined. `nil` when no bare date was given or `acceptsBareDate` is false. |
| `values` | `[String: String]` | One entry per keyword that appeared, keyed by `canonical`, value space-joined. Absent keywords have no entry. |
| `trailingText` | `String?` | Everything after `trailingTextKeyword`, space-joined. `nil` if that keyword did not appear. |

**Guarantees**
- A fully-quoted command line and its minimally-quoted equivalent produce an equal `ParsedCommand` (FR-002) — quotes are resolved by the shell before `parseCommand` runs.
- Re-ordering the `keyword value` pairs produces an equal `ParsedCommand` (FR-003).

---

## ArgumentError

`enum ArgumentError: LocalizedError`. One case per malformed-input class. Every case carries enough context to name the problem in the message (FR-005, SC-003).

| Case | Fires when | Message shape |
|---|---|---|
| `missingIdentifier(name: String)` | fewer leading tokens than `shape.identifiers.count` | `provide a <name>` |
| `unexpectedTokens([String])` | non-keyword tokens in the bare region when `acceptsBareDate` is false | `unexpected: <tokens>` (+ `list "<tokens>"` hint when a `list` keyword exists) |
| `unknownKeyword(String)` | a token where a keyword is expected is not a known keyword or alias | `unrecognized: <token>` |
| `missingValue(keyword: String)` | a keyword is the last token, or is immediately followed by another keyword | `<keyword> needs a value` |
| `duplicateKeyword(String)` | the same keyword (by canonical) appears twice | `<keyword> given twice` |
| `dateGivenTwice` | `bareDate` is non-nil **and** the `due`/`date` keyword also appeared | `date given two ways — use a bare date or due, not both` |

Reminders handlers wrap these: `catch let e as ArgumentError { throw ReminderHandlerError(e.errorDescription ?? "invalid arguments") }`.

---

## ParsedOptions (unchanged, RemindersLib)

Kept as-is — the domain DTO that `AddHandler`, `ChangeHandler`, and `parseReminderChanges` already consume. Only its *producer* changes.

| Field | Source after this change |
|---|---|
| `date` | `parsed.bareDate ?? parsed.values["due"] ?? ""` |
| `recurrence` | `parsed.values["repeat"] ?? ""` |
| `priority` | `parsed.values["priority"] ?? ""` |
| `url` | `parsed.values["url"] ?? ""` |
| `list` | `parsed.values["list"] ?? ""` |
| `note` | `parsed.trailingText ?? ""` |

`splitListAndOptions` and `parseOptions(_ s: String)` are deleted.

---

## Reminders CommandShape instances (RemindersLib/ReminderCommandShapes.swift)

```
add    → identifiers ["title"],          acceptsBareDate true,  keywords [list, priority, url, repeat, due], trailingText "note"
change → identifiers ["title"],          acceptsBareDate true,  keywords [list, priority, url, repeat, due], trailingText "note"
rename → identifiers ["title","new title"], acceptsBareDate false, keywords [list],                          trailingText nil
remove → identifiers ["title"],          acceptsBareDate false, keywords [list],                           trailingText nil
done   → identifiers ["title"],          acceptsBareDate false, keywords [list],                           trailingText nil
show   → identifiers ["title"],          acceptsBareDate false, keywords [list],                           trailingText nil
```

Keyword definitions:
- `list` — no aliases
- `priority` — no aliases
- `url` — no aliases
- `repeat` — aliases `repeats`, `repeating`, `repeated`
- `due` — aliases `date`
- `note` — trailing-text keyword (not in the `keywords` array)
