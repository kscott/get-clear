// ArgumentParserSpec.swift
//
// Tests for MailLib ArgumentParser — mapping a ParsedCommand onto ComposedMessage.

import GetClearKit
import MailLib
import Testing

@Suite("composeMessage")
struct ArgumentParserTests {
    @Suite("basic recipient")
    struct BasicRecipient {
        @Test("sets the to field")
        func setsToField() throws {
            let parsed = try parseCommand(["alice@example.com", "body", "hi"], shape: MailCommandShapes.send)
            #expect(composeMessage(from: parsed).to == "alice@example.com")
        }

        @Test("defaults subject to empty")
        func defaultsSubjectEmpty() throws {
            let parsed = try parseCommand(["alice@example.com", "body", "hi"], shape: MailCommandShapes.send)
            #expect(composeMessage(from: parsed).subject == "")
        }

        @Test("defaults attachments to empty")
        func defaultsAttachmentsEmpty() throws {
            let parsed = try parseCommand(["alice@example.com", "body", "hi"], shape: MailCommandShapes.send)
            #expect(composeMessage(from: parsed).attachments.isEmpty)
        }

        @Test("defaults cc to empty")
        func defaultsCcEmpty() throws {
            let parsed = try parseCommand(["alice@example.com", "body", "hi"], shape: MailCommandShapes.send)
            #expect(composeMessage(from: parsed).cc.isEmpty)
        }
    }

    @Suite("subject keyword")
    struct SubjectKeyword {
        @Test("captures a quoted multi-word subject")
        func capturesQuotedSubject() throws {
            let parsed = try parseCommand(
                ["alice", "subject", "Hello World", "body", "hi"], shape: MailCommandShapes.send
            )
            #expect(composeMessage(from: parsed).subject == "Hello World")
        }
    }

    @Suite("body keyword")
    struct BodyKeyword {
        @Test("captures body text to end of args")
        func capturesBodyToEnd() throws {
            let parsed = try parseCommand(
                ["alice", "subject", "Hi", "body", "Hello", "there"], shape: MailCommandShapes.send
            )
            #expect(composeMessage(from: parsed).body == "Hello there")
        }

        @Test("captures body containing apostrophes when passed as a single token")
        func capturesBodyWithApostrophes() throws {
            let body = "I wanted you to see it first so you're not caught off guard."
            let parsed = try parseCommand(["alice", "body", body], shape: MailCommandShapes.send)
            #expect(composeMessage(from: parsed).body == body)
        }

        @Test("captures body containing newlines when passed as a single token")
        func capturesBodyWithNewlines() throws {
            let body = "Line one.\nLine two.\nLine three."
            let parsed = try parseCommand(["alice", "body", body], shape: MailCommandShapes.send)
            #expect(composeMessage(from: parsed).body == body)
        }

        @Test("captures body containing em-dashes and asterisks when passed as a single token")
        func capturesBodyWithEmDashesAndAsterisks() throws {
            let body = "Join us — I can forward details to anyone who's interested.\n*Nursery available."
            let parsed = try parseCommand(["alice", "body", body], shape: MailCommandShapes.send)
            #expect(composeMessage(from: parsed).body == body)
        }
    }

    @Suite("cc keyword")
    struct CcKeyword {
        @Test("captures a single cc recipient")
        func capturesSingleCc() throws {
            let parsed = try parseCommand(
                ["alice", "cc", "bob@example.com", "body", "hi"], shape: MailCommandShapes.send
            )
            #expect(composeMessage(from: parsed).cc == ["bob@example.com"])
        }

        @Test("captures a quoted multi-word cc recipient")
        func capturesQuotedMultiWordCc() throws {
            let parsed = try parseCommand(
                ["alice", "cc", "Bob Jones", "subject", "Hi", "body", "hi"], shape: MailCommandShapes.send
            )
            #expect(composeMessage(from: parsed).cc == ["Bob Jones"])
        }

        @Test("captures multiple cc entries from repeated keyword")
        func capturesMultipleCc() throws {
            let parsed = try parseCommand(
                ["alice", "cc", "bob", "cc", "carol", "body", "hi"], shape: MailCommandShapes.send
            )
            #expect(composeMessage(from: parsed).cc == ["bob", "carol"])
        }
    }

    @Suite("attach keyword")
    struct AttachKeyword {
        @Test("captures a single attachment path")
        func capturesSingleAttachment() throws {
            let parsed = try parseCommand(
                ["alice", "attach", "/tmp/file.pdf", "body", "hi"], shape: MailCommandShapes.send
            )
            #expect(composeMessage(from: parsed).attachments == ["/tmp/file.pdf"])
        }

        @Test("captures multiple attachments from repeated keyword")
        func capturesMultipleAttachments() throws {
            let parsed = try parseCommand(
                ["alice", "attach", "/tmp/a.pdf", "attach", "/tmp/b.pdf", "body", "hi"], shape: MailCommandShapes.send
            )
            #expect(composeMessage(from: parsed).attachments.count == 2)
        }
    }

    @Suite("all keywords combined")
    struct AllKeywordsCombined {
        static func parse() throws -> ParsedCommand {
            try parseCommand(
                ["alice", "cc", "bob", "subject", "Meeting",
                 "attach", "/tmp/doc.pdf", "body", "See attached"], shape: MailCommandShapes.send
            )
        }

        @Test("captures to") func capturesTo() throws {
            #expect(try composeMessage(from: Self.parse()).to == "alice")
        }

        @Test("captures cc") func capturesCc() throws {
            #expect(try composeMessage(from: Self.parse()).cc == ["bob"])
        }

        @Test("captures subject") func capturesSubject() throws {
            #expect(try composeMessage(from: Self.parse()).subject == "Meeting")
        }

        @Test("captures attachment") func capturesAttachment() throws {
            #expect(try composeMessage(from: Self.parse()).attachments == ["/tmp/doc.pdf"])
        }

        @Test("captures body") func capturesBody() throws {
            #expect(try composeMessage(from: Self.parse()).body == "See attached")
        }
    }
}
