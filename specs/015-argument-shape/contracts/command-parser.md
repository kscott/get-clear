# Contract — `parseCommand` (GetClearKit)

```swift
// Sources/GetClearKit/CommandArguments.swift

public struct Keyword: Sendable, Equatable {
    public let canonical: String
    public let aliases: [String]
    public init(_ canonical: String, aliases: [String] = [])
}

public struct Identifier: Sendable, Equatable {
    public let name: String       // for error messages: "title", "new title", "list", "query"
    public let required: Bool
    public init(_ name: String, required: Bool = true)
}

public enum LeadingRegion: Sendable, Equatable {
    case none        // no tokens permitted between the identifiers and the first keyword
    case bareDate    // add / change — optional date; `due`/`date`/`on` filler stripped; guards "date given two ways"
}

public struct CommandShape: Sendable {
    public let identifiers: [Identifier]
    public let leading: LeadingRegion
    public let keywords: [Keyword]
    public let trailingTextKeyword: String?
    public init(
        identifiers: [Identifier] = [],
        leading: LeadingRegion = .none,
        keywords: [Keyword] = [],
        trailingTextKeyword: String? = nil
    )
}

public struct ParsedCommand: Equatable, Sendable {
    public let identifiers: [String]     // one entry per identifier that was present (optional ones may be absent)
    public let bareDate: String?
    public let values: [String: String]  // keyed by keyword canonical
    public let trailingText: String?
}

public enum ArgumentError: Error, LocalizedError, Equatable {
    case missingIdentifier(name: String)
    case unexpectedTokens([String])
    case unknownKeyword(String)
    case missingValue(keyword: String)
    case duplicateKeyword(String)
    case dateGivenTwice
    public var errorDescription: String? { /* see data-model.md */ }
}

/// Parse argv-after-the-command-name into a `ParsedCommand`, per `shape`.
/// Quotes are already resolved by the shell — this works on the token array only.
public func parseCommand(_ tokens: [String], shape: CommandShape) throws -> ParsedCommand
```

## The one rule

Every identifier is exactly one token, quoted by the person if it has a space. There is no "greedy up to the first keyword." A bare keyword word is never consumed as an identifier (`reminders add list` → `missingIdentifier`, quote to force). In a `.none` leading region a stray token is `unexpectedTokens` with a "quote it?" hint; in a `.bareDate` region it becomes the date string (and fails date parsing downstream if it is not one). The **only** value that does not need quoting is the trailing text field (`note`), which captures the rest of the line.

## Algorithm

1. **Identifiers.** For each `Identifier` in order: if the next token exists and is not a recognized keyword word, consume exactly one token. Otherwise:
   - `required` → `missingIdentifier(name:)`. When the blocker is a keyword word (`reminders add list`, `reminders rename "Buy milk" list`), the message names it and tells the user to quote: `provide a <name> — "<token>" is a keyword; quote it ("<token>") to use it as the <name>`. When nothing remains at all: `provide a <name>`.
   - optional → skip (leave the token for keyword parsing — `reminders list by created`).

   The keyword check applies uniformly to required and optional identifiers: a bare unquoted keyword word is never silently taken as a name. Quoting forces it (`reminders add "list"`).
2. **Leading region.** Collect tokens up to the first keyword (or `trailingTextKeyword`):
   - `.none` + any collected → `unexpectedTokens(collected)`. Catches `reminders remove "X" Bills`, `reminders find pick up milk`, `reminders list Household Bills`.
   - `.bareDate` + collected → join → `bareDate`, verbatim. No filler stripping here: `due` / `date` are keywords and never reach this region, and a leading `on` (`add "X" on march 1`) is left for the date parser, which tolerates it.
3. **Keyword pairs** until `trailingTextKeyword` or end:
   - not a known keyword/alias → `unknownKeyword`.
   - no value (end, or next token is a keyword) → `missingValue`.
   - canonical already seen → `duplicateKeyword`.
   - value = tokens up to the next keyword / `trailingTextKeyword` / end, space-joined.
4. `trailingTextKeyword` token → remaining tokens joined → `trailingText`; stop.
5. `bareDate != nil` **and** the `due`/`date` keyword also seen → `dateGivenTwice`.

## Behavioral contract

| Given | Then |
|---|---|
| a required identifier's token is missing | `missingIdentifier(name:)` — `provide a <name>` |
| a required identifier is blocked by a keyword word (`add list`) | `missingIdentifier(name:)` — names the token, tells the user to quote it |
| an identifier token containing a space (was quoted → one token) | consumed whole |
| extra token(s) after the identifiers with `.none` leading | `unexpectedTokens` + "quote it?" hint |
| `.bareDate` region present | `bareDate` captured verbatim; a leading `on` is left for the date parser |
| unknown token where a keyword is expected | `unknownKeyword` |
| keyword with no value | `missingValue` |
| same keyword twice | `duplicateKeyword` |
| `bareDate` + `due` keyword | `dateGivenTwice` |
| `trailingTextKeyword` seen | rest joined → `trailingText`; later keywords are literal |
| keywords reordered | equal `ParsedCommand` |
| every token quoted vs none | equal `ParsedCommand` |

## Non-goals

- No dates, priorities, recurrence, URLs, list existence, or sort-order validity — the tool validates the returned strings against its known values and MUST error (not silently drop) on an unrecognized one (FR-024).
- No `--flag` handling — dispatched earlier by `parseArgs`.
