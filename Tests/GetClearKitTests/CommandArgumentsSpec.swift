// CommandArgumentsSpec.swift
//
// Tests for GetClearKit CommandArguments — the shared argument parser.

import GetClearKit
import Testing

private let titleShape = CommandShape(
    identifiers: [Identifier("title")],
    leading: .none,
    keywords: [Keyword("list"), Keyword("priority")]
)

private let bareDateRangeShape = CommandShape(
    identifiers: [Identifier("title")],
    leading: .bareDateRange,
    keywords: [Keyword("due", aliases: ["date"]), Keyword("list")],
    trailingTextKeyword: "note"
)

private struct TestToolError: Error, Equatable {
    let message: String
    init(_ message: String) {
        self.message = message
    }
}

private let optionalFilterShape = CommandShape(
    identifiers: [Identifier("list", required: false)],
    leading: .none,
    keywords: [Keyword("by")]
)

private let requiredTrailingTextShape = CommandShape(
    identifiers: [Identifier("contact")],
    trailingTextKeyword: "message",
    requiresTrailingText: true
)

private let repeatableKeywordShape = CommandShape(
    identifiers: [Identifier("to")],
    keywords: [Keyword("cc", repeatable: true), Keyword("subject")]
)

@Suite("parseCommand")
struct CommandArgumentsTests {
    @Suite("identifiers")
    struct Identifiers {
        @Test("a required identifier is consumed from a single token")
        func requiredIdentifierConsumed() throws {
            let parsed = try parseCommand(["Pay rent"], shape: titleShape)
            #expect(parsed.identifiers == ["Pay rent"])
        }

        @Test("a missing required identifier at end of input throws missingIdentifier")
        func missingRequiredIdentifier() {
            #expect(throws: ArgumentError.missingIdentifier(name: "title")) {
                try parseCommand([], shape: titleShape)
            }
        }

        @Test("a required identifier blocked by a keyword word throws missingIdentifier naming the token")
        func requiredIdentifierBlockedByKeyword() {
            #expect(throws: ArgumentError.missingIdentifier(name: "title", blockedBy: "list")) {
                try parseCommand(["list"], shape: titleShape)
            }
        }

        @Test("an absent optional identifier leaves the token for keyword parsing")
        func optionalIdentifierSkipsKeywordWord() throws {
            let parsed = try parseCommand(["by", "created"], shape: optionalFilterShape)
            #expect(parsed.identifiers.isEmpty && parsed.values["by"] == "created")
        }

        @Test("a present optional identifier is consumed")
        func optionalIdentifierPresent() throws {
            let parsed = try parseCommand(["Household Bills"], shape: optionalFilterShape)
            #expect(parsed.identifiers == ["Household Bills"])
        }
    }

    @Suite("leading region")
    struct LeadingRegionTests {
        @Test(".none rejects a stray token as unexpectedTokens")
        func noneRejectsStrayToken() {
            #expect(throws: ArgumentError.unexpectedTokens(["Bills"])) {
                try parseCommand(["Pay rent", "Bills"], shape: titleShape)
            }
        }

        @Test(".bareDateRange captures the leading phrase verbatim")
        func bareDateCapturedVerbatim() throws {
            let parsed = try parseCommand(["Pay rent", "march", "1"], shape: bareDateRangeShape)
            #expect(parsed.bareDateRange == "march 1")
        }

        @Test(".bareDateRange is nil when nothing precedes the first keyword")
        func bareDateNilWhenAbsent() throws {
            let parsed = try parseCommand(["Pay rent", "list", "Bills"], shape: bareDateRangeShape)
            #expect(parsed.bareDateRange == nil)
        }
    }

    @Suite("keyword values")
    struct KeywordValues {
        @Test("a single-token keyword value is captured")
        func singleTokenValue() throws {
            let parsed = try parseCommand(["Pay rent", "list", "Bills"], shape: titleShape)
            #expect(parsed.values["list"] == "Bills")
        }

        @Test("the due keyword's value is space-joined up to the next keyword, unlike other keywords")
        func multiTokenValue() throws {
            let parsed = try parseCommand(["Pay rent", "due", "next", "friday"], shape: bareDateRangeShape)
            #expect(parsed.values["due"] == "next friday")
        }

        @Test("a non-due keyword's value is capped at exactly one token")
        func nonDueValueCappedAtOneToken() throws {
            let parsed = try parseCommand(["Pay rent", "list", "Bills", "priority", "high"], shape: titleShape)
            #expect(parsed.values["list"] == "Bills" && parsed.values["priority"] == "high")
        }

        @Test("an alias resolves to its canonical keyword")
        func aliasResolvesToCanonical() throws {
            let parsed = try parseCommand(["Pay rent", "date", "friday"], shape: bareDateRangeShape)
            #expect(parsed.values["due"] == "friday")
        }

        @Test("keyword order does not affect the parsed result")
        func keywordOrderIndependence() throws {
            let a = try parseCommand(["Pay rent", "list", "Bills", "due", "friday"], shape: bareDateRangeShape)
            let b = try parseCommand(["Pay rent", "due", "friday", "list", "Bills"], shape: bareDateRangeShape)
            #expect(a == b)
        }
    }

    @Suite("repeatable keyword")
    struct RepeatableKeyword {
        @Test("a single occurrence is collected into repeatedValues")
        func singleOccurrence() throws {
            let parsed = try parseCommand(["alice", "cc", "bob"], shape: repeatableKeywordShape)
            #expect(parsed.repeatedValues["cc"] == ["bob"])
        }

        @Test("repeated occurrences are collected in order, not an error")
        func repeatedOccurrencesInOrder() throws {
            let parsed = try parseCommand(["alice", "cc", "bob", "cc", "carol"], shape: repeatableKeywordShape)
            #expect(parsed.repeatedValues["cc"] == ["bob", "carol"])
        }

        @Test("a repeatable keyword that never appears is absent from repeatedValues")
        func absentWhenNeverGiven() throws {
            let parsed = try parseCommand(["alice"], shape: repeatableKeywordShape)
            #expect(parsed.repeatedValues["cc"] == nil)
        }

        @Test("a repeatable keyword never appears in values")
        func neverInValues() throws {
            let parsed = try parseCommand(["alice", "cc", "bob"], shape: repeatableKeywordShape)
            #expect(parsed.values["cc"] == nil)
        }

        @Test("a non-repeatable keyword given twice still throws duplicateKeyword")
        func nonRepeatableStillThrows() {
            #expect(throws: ArgumentError.duplicateKeyword("subject")) {
                try parseCommand(
                    ["alice", "subject", "Hi", "subject", "Bye"], shape: repeatableKeywordShape
                )
            }
        }
    }

    @Suite("trailing text")
    struct TrailingText {
        @Test("trailing text captures everything to end, including later keyword words")
        func trailingTextCapturesToEnd() throws {
            let parsed = try parseCommand(
                ["Pay rent", "note", "ask", "about", "list", "pricing"], shape: bareDateRangeShape
            )
            #expect(parsed.trailingText == "ask about list pricing")
        }

        @Test("trailingText is nil when the trailing keyword never appears")
        func trailingTextNilWhenAbsent() throws {
            let parsed = try parseCommand(["Pay rent"], shape: bareDateRangeShape)
            #expect(parsed.trailingText == nil)
        }
    }

    @Suite("required trailing text")
    struct RequiredTrailingText {
        @Test("parses when the trailing keyword has a value")
        func parsesWithValue() throws {
            let parsed = try parseCommand(["Marcus", "message", "running late"], shape: requiredTrailingTextShape)
            #expect(parsed.trailingText == "running late")
        }

        @Test("missingValue fires when the trailing keyword never appears")
        func missingValueWhenAbsent() {
            #expect(throws: ArgumentError.missingValue(keyword: "message")) {
                try parseCommand(["Marcus"], shape: requiredTrailingTextShape)
            }
        }

        @Test("missingValue fires when the trailing keyword is given with no value")
        func missingValueWhenEmpty() {
            #expect(throws: ArgumentError.missingValue(keyword: "message")) {
                try parseCommand(["Marcus", "message"], shape: requiredTrailingTextShape)
            }
        }

        @Test("a shape with no trailingTextKeyword ignores requiresTrailingText")
        func ignoredWithoutTrailingTextKeyword() throws {
            let shape = CommandShape(identifiers: [Identifier("title")], requiresTrailingText: true)
            let parsed = try parseCommand(["Pay rent"], shape: shape)
            #expect(parsed.trailingText == nil)
        }
    }

    @Suite("quoting invariance")
    struct QuotingInvariance {
        @Test("a fully-quoted token stream parses identically to its minimally-quoted equivalent")
        func fullyQuotedEqualsMinimallyQuoted() throws {
            let fullyQuoted = try parseCommand(["Pay rent", "due", "next friday"], shape: bareDateRangeShape)
            let minimallyQuoted = try parseCommand(["Pay rent", "due", "next", "friday"], shape: bareDateRangeShape)
            #expect(fullyQuoted == minimallyQuoted)
        }
    }

    @Suite("wrapError overload")
    struct WrapErrorOverload {
        @Test("returns the same ParsedCommand as the unwrapped overload on success")
        func returnsSameResultOnSuccess() throws {
            let plain = try parseCommand(["Pay rent", "list", "Bills"], shape: titleShape)
            let wrapped = try parseCommand(
                ["Pay rent", "list", "Bills"], shape: titleShape, wrapError: TestToolError.init
            )
            #expect(plain == wrapped)
        }

        @Test("wraps an ArgumentError into the caller's error type, carrying its message")
        func wrapsArgumentErrorMessage() {
            #expect(throws: TestToolError("provide a title")) {
                try parseCommand([], shape: titleShape, wrapError: TestToolError.init)
            }
        }
    }

    @Suite("ArgumentError cases")
    struct ArgumentErrorCases {
        @Test("errorDescription delegates to message, for LocalizedError conformance")
        func errorDescriptionDelegatesToMessage() {
            let error = ArgumentError.dateGivenTwice
            #expect(error.errorDescription == error.message)
        }

        @Test("missingIdentifier fires when a required identifier has no token")
        func missingIdentifierCase() {
            #expect(throws: ArgumentError.missingIdentifier(name: "title")) {
                try parseCommand([], shape: titleShape)
            }
        }

        @Test("unexpectedTokens fires for a stray token in a .none leading region")
        func unexpectedTokensCase() {
            #expect(throws: ArgumentError.unexpectedTokens(["Bills"])) {
                try parseCommand(["Pay rent", "Bills"], shape: titleShape)
            }
        }

        @Test("unknownKeyword fires for a second, unquoted word left over after a single-token value")
        func unknownKeywordCase() {
            #expect(throws: ArgumentError.unknownKeyword("Bills")) {
                try parseCommand(["Pay rent", "list", "Household", "Bills"], shape: titleShape)
            }
        }

        @Test("missingValue fires when a keyword is the last token")
        func missingValueCase() {
            #expect(throws: ArgumentError.missingValue(keyword: "priority")) {
                try parseCommand(["Pay rent", "priority"], shape: titleShape)
            }
        }

        @Test("duplicateKeyword fires when the same canonical keyword appears twice")
        func duplicateKeywordCase() {
            #expect(throws: ArgumentError.duplicateKeyword("list")) {
                try parseCommand(["Pay rent", "list", "A", "list", "B"], shape: titleShape)
            }
        }

        @Test("dateGivenTwice fires when a bare date and the due keyword both appear")
        func dateGivenTwiceCase() {
            #expect(throws: ArgumentError.dateGivenTwice) {
                try parseCommand(["Pay rent", "march", "1", "due", "none"], shape: bareDateRangeShape)
            }
        }
    }
}
