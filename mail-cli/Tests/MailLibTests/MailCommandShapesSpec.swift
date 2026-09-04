// MailCommandShapesSpec.swift
//
// Tests for MailCommandShapes — each shape parses its documented forms and
// rejects the malformed ones.

import GetClearKit
import MailLib
import Testing

@Suite("MailCommandShapes")
struct MailCommandShapesTests {
    @Suite("send / draft")
    struct SendDraft {
        static let allShapes: [(String, CommandShape)] = [
            ("send", MailCommandShapes.send),
            ("draft", MailCommandShapes.draft)
        ]

        @Test("parses a recipient and a body", arguments: allShapes)
        func parsesRecipientAndBody(name: String, shape: CommandShape) throws {
            let parsed = try parseCommand(["alice", "body", "hi"], shape: shape)
            #expect(parsed.identifiers == ["alice"] && parsed.trailingText == "hi")
        }

        @Test("no recipient throws missingIdentifier", arguments: allShapes)
        func noRecipientThrows(name: String, shape: CommandShape) {
            #expect(throws: ArgumentError.missingIdentifier(name: "to")) {
                try parseCommand([], shape: shape)
            }
        }

        @Test("a bare 'body' where the recipient belongs throws missingIdentifier naming it as the blocker",
              arguments: allShapes)
        func recipientBlockedByKeywordThrows(name: String, shape: CommandShape) {
            #expect(throws: ArgumentError.missingIdentifier(name: "to", blockedBy: "body")) {
                try parseCommand(["body", "hi"], shape: shape)
            }
        }

        @Test("no body throws missingValue", arguments: allShapes)
        func noBodyThrows(name: String, shape: CommandShape) {
            #expect(throws: ArgumentError.missingValue(keyword: "body")) {
                try parseCommand(["alice"], shape: shape)
            }
        }

        @Test("body given with no value throws missingValue", arguments: allShapes)
        func emptyBodyThrows(name: String, shape: CommandShape) {
            #expect(throws: ArgumentError.missingValue(keyword: "body")) {
                try parseCommand(["alice", "body"], shape: shape)
            }
        }

        @Test("cc and attach each accept repeated occurrences", arguments: allShapes)
        func ccAndAttachRepeat(name: String, shape: CommandShape) throws {
            let parsed = try parseCommand(
                ["alice", "cc", "bob", "cc", "carol", "attach", "a.pdf", "attach", "b.pdf", "body", "hi"],
                shape: shape
            )
            #expect(parsed.repeatedValues["cc"] == ["bob", "carol"])
            #expect(parsed.repeatedValues["attach"] == ["a.pdf", "b.pdf"])
        }

        @Test("a second subject throws duplicateKeyword", arguments: allShapes)
        func duplicateSubjectThrows(name: String, shape: CommandShape) {
            #expect(throws: ArgumentError.duplicateKeyword("subject")) {
                try parseCommand(["alice", "subject", "Hi", "subject", "Bye", "body", "hi"], shape: shape)
            }
        }
    }

    @Suite("find")
    struct Find {
        @Test("parses a quoted multi-word query")
        func parsesQuotedQuery() throws {
            let parsed = try parseCommand(["quarterly report"], shape: MailCommandShapes.find)
            #expect(parsed.identifiers == ["quarterly report"])
        }

        @Test("an unquoted multi-word query throws unexpectedTokens")
        func unquotedQueryThrows() {
            #expect(throws: ArgumentError.unexpectedTokens(["report"])) {
                try parseCommand(["quarterly", "report"], shape: MailCommandShapes.find)
            }
        }

        @Test("no query throws missingIdentifier")
        func noQueryThrows() {
            #expect(throws: ArgumentError.missingIdentifier(name: "query")) {
                try parseCommand([], shape: MailCommandShapes.find)
            }
        }
    }

    @Suite("open")
    struct Open {
        @Test("parses with no arguments")
        func parsesBare() throws {
            let parsed = try parseCommand([], shape: MailCommandShapes.open)
            #expect(parsed.identifiers.isEmpty)
        }

        @Test("a stray token throws unexpectedTokens")
        func strayTokenThrows() {
            #expect(throws: ArgumentError.unexpectedTokens(["extra"])) {
                try parseCommand(["extra"], shape: MailCommandShapes.open)
            }
        }
    }
}
