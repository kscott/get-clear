# Contract — `parseCommand` (GetClearKit)

The public interface the shared parser exposes to every tool.

```swift
// Sources/GetClearKit/CommandArguments.swift

public struct Keyword: Sendable, Equatable {
    public let canonical: String
    public let aliases: [String]
    public init(_ canonical: String, aliases: [String] = [])
}

public struct CommandShape: Sendable {
    public let identifiers: [String]
    public let acceptsBareDate: Bool
    public let keywords: [Keyword]
    public let trailingTextKeyword: String?
    public init(
        identifiers: [String] = [],
        acceptsBareDate: Bool = false,
        keywords: [Keyword] = [],
        trailingTextKeyword: String? = nil
    )
}

public struct ParsedCommand: Equatable, Sendable {
    public let identifiers: [String]
    public let bareDate: String?
    public let values: [String: String]
    public let trailingText: String?
}

public enum ArgumentError: Error, LocalizedError, Equatable {
    case missingIdentifier(name: String)
    case unexpectedTokens([String])
    case unknownKeyword(String)
    case missingValue(keyword: String)
    case duplicateKeyword(String)
    case dateGivenTwice
    public var errorDescription: String? { /* see data-model.md message shapes */ }
}

/// Parse `tokens` (argv after the command name) into a `ParsedCommand`, per `shape`.
/// Quotes are already resolved by the shell; this operates on the token array only.
public func parseCommand(_ tokens: [String], shape: CommandShape) throws -> ParsedCommand
```

## Behavioral contract

| Given | Then |
|---|---|
| `tokens.count < shape.identifiers.count` | throws `missingIdentifier(name:)` for the first missing one |
| tokens after the identifiers, before any keyword, `acceptsBareDate == true` | joined (minus a leading `due`/`date`/`on`) → `bareDate` |
| same, `acceptsBareDate == false`, region non-empty | throws `unexpectedTokens(region)` |
| a token where a keyword is expected, not matching any `canonical` or `alias` | throws `unknownKeyword(token)` |
| a keyword with no value (end of tokens, or next token is a keyword) | throws `missingValue(keyword: canonical)` |
| the same keyword (by canonical) twice | throws `duplicateKeyword(canonical)` |
| `bareDate` produced **and** `due`/`date` keyword present | throws `dateGivenTwice` |
| token equal to `trailingTextKeyword` | remaining tokens joined → `trailingText`; parsing stops |
| keyword values are multi-token | joined with a single space, up to the next keyword / trailing-text keyword / end |
| the same command, keywords reordered | equal `ParsedCommand` |
| the same command, every token separately quoted vs not | equal `ParsedCommand` |

## Non-goals

- No knowledge of dates, priorities, recurrence, URLs, or list existence — those are the tool's job on the returned strings.
- No `--flag` handling — the suite has none beyond `--help` / `--version`, dispatched earlier by `parseArgs`.
- Phase 1 does not model an optional leading *filter* positional (needed by `reminders list`) or a from-position-0 trailing text (needed by `reminders find`). Follow-up in research.md R4.
