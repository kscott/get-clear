// ArgumentParserSpec.swift
//
// Tests for MailLib ArgumentParser — send argument parsing into ComposedMessage.

import Foundation
import MailLib
import Testing

@Suite("parseSendArgs")
struct ArgumentParserTests {
    @Suite("basic recipient")
    struct BasicRecipient {
        @Test("sets the to field")
        func setsToField() {
            #expect(parseSendArgs(["alice@example.com"])?.to == "alice@example.com")
        }

        @Test("defaults subject to empty")
        func defaultsSubjectEmpty() {
            #expect(parseSendArgs(["alice@example.com"])?.subject == "")
        }

        @Test("defaults body to empty")
        func defaultsBodyEmpty() {
            #expect(parseSendArgs(["alice@example.com"])?.body == "")
        }

        @Test("defaults isDraft to false")
        func defaultsIsDraftFalse() {
            #expect(parseSendArgs(["alice@example.com"])?.isDraft == false)
        }

        @Test("defaults attachments to empty")
        func defaultsAttachmentsEmpty() {
            #expect(parseSendArgs(["alice@example.com"])?.attachments.isEmpty == true)
        }
    }

    @Suite("multi-word recipient")
    struct MultiWordRecipient {
        @Test("joins words before the first keyword as the recipient")
        func joinsWordsAsRecipient() {
            #expect(parseSendArgs(["Jane", "Doe", "subject", "Hi"])?.to == "Jane Doe")
        }

        @Test("captures subject after recipient")
        func capturesSubjectAfterRecipient() {
            #expect(parseSendArgs(["Jane", "Doe", "subject", "Hi"])?.subject == "Hi")
        }
    }

    @Suite("subject keyword")
    struct SubjectKeyword {
        @Test("captures a multi-word subject")
        func capturesMultiWordSubject() {
            #expect(parseSendArgs(["alice", "subject", "Hello", "World"])?.subject == "Hello World")
        }
    }

    @Suite("body keyword")
    struct BodyKeyword {
        @Test("captures body text to end of args")
        func capturesBodyToEnd() {
            #expect(parseSendArgs(["alice", "subject", "Hi", "body", "Hello", "there"])?.body == "Hello there")
        }

        @Test("captures body containing apostrophes when passed as a single token")
        func capturesBodyWithApostrophes() {
            let body = "I wanted you to see it first so you're not caught off guard."
            #expect(parseSendArgs(["alice", "body", body])?.body == body)
        }

        @Test("captures body containing newlines when passed as a single token")
        func capturesBodyWithNewlines() {
            let body = "Line one.\nLine two.\nLine three."
            #expect(parseSendArgs(["alice", "body", body])?.body == body)
        }

        @Test("captures body containing em-dashes and asterisks when passed as a single token")
        func capturesBodyWithEmDashesAndAsterisks() {
            let body = "Join us — I can forward details to anyone who's interested.\n*Nursery available."
            #expect(parseSendArgs(["alice", "body", body])?.body == body)
        }
    }

    @Suite("cc keyword")
    struct CcKeyword {
        @Test("captures a single cc recipient")
        func capturesSingleCc() {
            #expect(parseSendArgs(["alice", "cc", "bob@example.com"])?.cc.first == "bob@example.com")
        }

        @Test("captures a multi-word cc recipient")
        func capturesMultiWordCc() {
            #expect(parseSendArgs(["alice", "cc", "Bob", "Jones", "subject", "Hi"])?.cc.first == "Bob Jones")
        }

        @Test("captures multiple cc entries from repeated keyword")
        func capturesMultipleCc() {
            #expect(parseSendArgs(["alice", "cc", "bob", "cc", "carol"])?.cc == ["bob", "carol"])
        }
    }

    @Suite("attach keyword")
    struct AttachKeyword {
        @Test("captures a single attachment path")
        func capturesSingleAttachment() {
            #expect(parseSendArgs(["alice", "attach", "/tmp/file.pdf"])?.attachments.first == "/tmp/file.pdf")
        }

        @Test("captures multiple attachments from repeated keyword")
        func capturesMultipleAttachments() {
            #expect(parseSendArgs(["alice", "attach", "/tmp/a.pdf", "attach", "/tmp/b.pdf"])?.attachments.count == 2)
        }
    }

    @Suite("--draft flag")
    struct DraftFlag {
        @Test("sets isDraft when flag appears before recipient")
        func draftBeforeRecipient() {
            #expect(parseSendArgs(["--draft", "alice", "subject", "Hi"])?.isDraft == true)
        }

        @Test("sets isDraft when flag appears at end")
        func draftAtEnd() {
            #expect(parseSendArgs(["alice", "subject", "Hi", "--draft"])?.isDraft == true)
        }
    }

    @Suite("all keywords combined")
    struct AllKeywordsCombined {
        let args = ["alice", "cc", "bob", "subject", "Meeting",
                    "attach", "/tmp/doc.pdf", "body", "See attached"]

        @Test("captures to") func capturesTo() {
            #expect(parseSendArgs(args)?.to == "alice")
        }

        @Test("captures cc") func capturesCc() {
            #expect(parseSendArgs(args)?.cc == ["bob"])
        }

        @Test("captures subject") func capturesSubject() {
            #expect(parseSendArgs(args)?.subject == "Meeting")
        }

        @Test("captures attachment") func capturesAttachment() {
            #expect(parseSendArgs(args)?.attachments == ["/tmp/doc.pdf"])
        }

        @Test("captures body") func capturesBody() {
            #expect(parseSendArgs(args)?.body == "See attached")
        }
    }

    @Suite("invalid input")
    struct InvalidInput {
        @Test("returns nil for empty args")
        func nilForEmptyArgs() {
            #expect(parseSendArgs([]) == nil)
        }

        @Test("returns nil when no recipient is present")
        func nilWhenNoRecipient() {
            #expect(parseSendArgs(["subject", "Hi"]) == nil)
        }
    }
}
