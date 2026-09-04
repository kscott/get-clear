// TextCommandShapesSpec.swift
//
// Tests for TextCommandShapes — each shape parses its documented forms and
// rejects the malformed ones.

import GetClearKit
import Testing
import TextLib

@Suite("TextCommandShapes")
struct TextCommandShapesTests {
    @Suite("send")
    struct Send {
        @Test("parses a contact and a message")
        func parsesContactAndMessage() throws {
            let parsed = try parseCommand(["Marcus", "message", "running late"], shape: TextCommandShapes.send)
            #expect(parsed.identifiers == ["Marcus"] && parsed.trailingText == "running late")
        }

        @Test("no message keyword throws missingValue — the message is required")
        func noMessageThrows() {
            #expect(throws: ArgumentError.missingValue(keyword: "message")) {
                try parseCommand(["Marcus"], shape: TextCommandShapes.send)
            }
        }

        @Test("message given with no value throws missingValue")
        func emptyMessageThrows() {
            #expect(throws: ArgumentError.missingValue(keyword: "message")) {
                try parseCommand(["Marcus", "message"], shape: TextCommandShapes.send)
            }
        }

        @Test("no contact throws missingIdentifier")
        func noContactThrows() {
            #expect(throws: ArgumentError.missingIdentifier(name: "contact")) {
                try parseCommand([], shape: TextCommandShapes.send)
            }
        }

        @Test("a stray token before the message keyword throws unexpectedTokens")
        func strayTokenThrows() {
            #expect(throws: ArgumentError.unexpectedTokens(["hey"])) {
                try parseCommand(["Marcus", "hey", "message", "hi"], shape: TextCommandShapes.send)
            }
        }
    }

    @Suite("open")
    struct Open {
        @Test("parses with no arguments")
        func parsesBare() throws {
            let parsed = try parseCommand([], shape: TextCommandShapes.open)
            #expect(parsed.identifiers.isEmpty)
        }

        @Test("a stray token throws unexpectedTokens")
        func strayTokenThrows() {
            #expect(throws: ArgumentError.unexpectedTokens(["extra"])) {
                try parseCommand(["extra"], shape: TextCommandShapes.open)
            }
        }
    }
}
