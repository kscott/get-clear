// CommandArguments.swift
//
// One shared argument parser for the whole suite, driven by a per-command CommandShape.
// Pure — tokens in, ParsedCommand out. No Apple framework dependencies.
//
// The one rule: every identifier is exactly one token, quoted by the caller if it
// contains a space. There is no "greedy up to the first keyword." A bare unquoted
// keyword word is never consumed as an identifier. The only value that does not need
// quoting is the trailing text field, which captures the rest of the line.
//
// See specs/015-argument-shape/contracts/command-parser.md for the full contract.

import Foundation

public struct Identifier: Sendable, Equatable {
    public let name: String
    public let required: Bool

    public init(_ name: String, required: Bool = true) {
        self.name = name
        self.required = required
    }
}

public enum LeadingRegion: Sendable, Equatable {
    /// No tokens permitted between the identifiers and the first keyword.
    case none
    /// Optional bare date or range, captured verbatim; guards "date given two ways" against a due/date keyword.
    case bareDateRange
}

public struct Keyword: Sendable, Equatable {
    public let canonical: String
    public let aliases: [String]

    public init(_ canonical: String, aliases: [String] = []) {
        self.canonical = canonical
        self.aliases = aliases
    }
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
    ) {
        self.identifiers = identifiers
        self.leading = leading
        self.keywords = keywords
        self.trailingTextKeyword = trailingTextKeyword
    }

    /// No identifiers, no keywords — any token at all is a stray token. The shape for every
    /// command that takes no arguments (reminders' `lists`/`open`, calendar's `today`/`week`/
    /// `calendars`/`setup`/`open`, contacts' `lists`/`open`, …) — one shared constant instead of
    /// each tool re-declaring an identical empty `CommandShape()`.
    public static let empty = CommandShape()
}

public struct ParsedCommand: Equatable, Sendable {
    /// One entry per identifier that was present — optional identifiers may be absent.
    public let identifiers: [String]
    public let bareDateRange: String?
    /// Keyed by keyword canonical, space-joined value.
    public let values: [String: String]
    public let trailingText: String?

    public init(identifiers: [String], bareDateRange: String?, values: [String: String], trailingText: String?) {
        self.identifiers = identifiers
        self.bareDateRange = bareDateRange
        self.values = values
        self.trailingText = trailingText
    }
}

public enum ArgumentError: Error, LocalizedError, Equatable {
    case missingIdentifier(name: String, blockedBy: String? = nil)
    case unexpectedTokens([String])
    case unknownKeyword(String)
    case missingValue(keyword: String)
    case duplicateKeyword(String)
    case dateGivenTwice

    /// Every case produces a message — unlike `errorDescription`, this is never nil, so
    /// callers never need a fallback string they can't actually exercise in a test.
    public var message: String {
        switch self {
        case let .missingIdentifier(name, blockedBy):
            if let blockedBy {
                return "provide a \(name) — \"\(blockedBy)\" is a keyword; quote it (\"\(blockedBy)\") to use it as the \(name)"
            }
            return "provide a \(name)"
        case let .unexpectedTokens(tokens):
            let joined = tokens.joined(separator: " ")
            return "unexpected: \(joined) — if that is part of the name, quote it as one argument; " +
                "otherwise introduce it with a keyword"
        case let .unknownKeyword(token):
            return "unrecognized: \(token)"
        case let .missingValue(keyword):
            return "\(keyword) needs a value"
        case let .duplicateKeyword(keyword):
            return "\(keyword) given twice"
        case .dateGivenTwice:
            return "date given two ways — use a bare date or due, not both"
        }
    }

    public var errorDescription: String? {
        message
    }
}

/// Parse argv-after-the-command-name into a `ParsedCommand`, per `shape`, wrapping any
/// `ArgumentError` into the caller's own tool-specific error type via `wrapError`.
///
/// Every tool's handlers wrap `ArgumentError` into their own domain error the same way —
/// this overload centralizes the catch/rethrow so a handler never writes that boilerplate
/// itself: `try parseCommand(tokens, shape: shape, wrapError: MyToolError.init)`.
public func parseCommand(
    _ tokens: [String], shape: CommandShape, wrapError: (String) -> some Error
) throws -> ParsedCommand {
    do {
        return try parseCommand(tokens, shape: shape)
    } catch let e as ArgumentError {
        throw wrapError(e.message)
    }
}

/// Parse argv-after-the-command-name into a `ParsedCommand`, per `shape`.
/// Quotes are already resolved by the shell — this works on the token array only.
public func parseCommand(_ tokens: [String], shape: CommandShape) throws -> ParsedCommand {
    var remaining = tokens[...]
    let keywordWords = commandKeywordWords(shape)

    let identifiers = try consumeIdentifiers(from: &remaining, shape: shape, keywordWords: keywordWords)
    let bareDateRange = try consumeLeadingRegion(from: &remaining, shape: shape, keywordWords: keywordWords)
    let (values, trailingText) = try consumeKeywordPairs(from: &remaining, shape: shape, keywordWords: keywordWords)

    // A bare date/range and a due/date keyword can't both be given.
    if bareDateRange != nil, values["due"] != nil {
        throw ArgumentError.dateGivenTwice
    }

    return ParsedCommand(
        identifiers: identifiers, bareDateRange: bareDateRange, values: values, trailingText: trailingText
    )
}

/// Consumes one token per `Identifier` in order; a bare keyword word is never taken as a name.
private func consumeIdentifiers(
    from remaining: inout ArraySlice<String>, shape: CommandShape, keywordWords: Set<String>
) throws -> [String] {
    var identifiers: [String] = []
    for identifier in shape.identifiers {
        guard let next = remaining.first else {
            if identifier.required {
                throw ArgumentError.missingIdentifier(name: identifier.name)
            }
            continue
        }
        if isKeywordWord(next, in: keywordWords) {
            if identifier.required {
                throw ArgumentError.missingIdentifier(name: identifier.name, blockedBy: next)
            }
            continue
        }
        identifiers.append(next)
        remaining = remaining.dropFirst()
    }
    return identifiers
}

/// Collects tokens up to the first keyword (or trailingTextKeyword) and interprets them per `shape.leading`.
private func consumeLeadingRegion(
    from remaining: inout ArraySlice<String>, shape: CommandShape, keywordWords: Set<String>
) throws -> String? {
    var leadingTokens: [String] = []
    while let next = remaining.first, !isKeywordWord(next, in: keywordWords) {
        leadingTokens.append(next)
        remaining = remaining.dropFirst()
    }
    guard !leadingTokens.isEmpty else { return nil }
    switch shape.leading {
    case .none:
        throw ArgumentError.unexpectedTokens(leadingTokens)
    case .bareDateRange:
        return leadingTokens.joined(separator: " ")
    }
}

/// Consumes `keyword value` pairs until `trailingTextKeyword` or end of input.
///
/// A keyword's value is exactly one token (quoted if it has a space) — the same rule as an
/// identifier — with one exception: the due/date keyword's value is free-form, collected
/// greedily like the bareDateRange region, because it is the same field (FR-013). This also keeps
/// unknownKeyword reachable: a single-token value collector leaves a stray trailing word
/// exposed at the top of the next iteration instead of silently absorbing it into the
/// previous value.
private func consumeKeywordPairs(
    from remaining: inout ArraySlice<String>, shape: CommandShape, keywordWords: Set<String>
) throws -> (values: [String: String], trailingText: String?) {
    var values: [String: String] = [:]
    var trailingText: String?

    while let token = remaining.first {
        remaining = remaining.dropFirst()
        guard let canonical = canonicalKeyword(for: token, in: shape) else {
            throw ArgumentError.unknownKeyword(token)
        }

        if canonical == shape.trailingTextKeyword {
            trailingText = remaining.joined(separator: " ")
            remaining = remaining[remaining.endIndex...]
            break
        }

        if values[canonical] != nil {
            throw ArgumentError.duplicateKeyword(canonical)
        }

        var valueTokens: [String] = []
        if canonical == dateKeywordCanonical {
            while let next = remaining.first, !isKeywordWord(next, in: keywordWords) {
                valueTokens.append(next)
                remaining = remaining.dropFirst()
            }
        } else if let next = remaining.first, !isKeywordWord(next, in: keywordWords) {
            valueTokens.append(next)
            remaining = remaining.dropFirst()
        }
        guard !valueTokens.isEmpty else {
            throw ArgumentError.missingValue(keyword: canonical)
        }
        values[canonical] = valueTokens.joined(separator: " ")
    }

    return (values, trailingText)
}

private func isKeywordWord(_ token: String, in keywordWords: Set<String>) -> Bool {
    keywordWords.contains(token.lowercased())
}

/// The one keyword whose value is free-form multi-token, mirroring the `.bareDateRange` region —
/// `due`/`date` names the same field the bare date/range fills, just introduced explicitly (FR-013).
private let dateKeywordCanonical = "due"

private func commandKeywordWords(_ shape: CommandShape) -> Set<String> {
    var words = Set<String>()
    for keyword in shape.keywords {
        words.insert(keyword.canonical.lowercased())
        for alias in keyword.aliases {
            words.insert(alias.lowercased())
        }
    }
    if let trailingTextKeyword = shape.trailingTextKeyword {
        words.insert(trailingTextKeyword.lowercased())
    }
    return words
}

private func canonicalKeyword(for token: String, in shape: CommandShape) -> String? {
    let lower = token.lowercased()
    if lower == shape.trailingTextKeyword?.lowercased() {
        return shape.trailingTextKeyword
    }
    for keyword in shape.keywords {
        if keyword.canonical.lowercased() == lower || keyword.aliases.contains(where: { $0.lowercased() == lower }) {
            return keyword.canonical
        }
    }
    return nil
}
