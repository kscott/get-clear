// ArgumentParserSpec.swift
//
// Tests for MailLib ArgumentParser — send argument parsing into ComposedMessage.

import Foundation
import MailLib
import Nimble
import Quick

final class ArgumentParserSpec: QuickSpec {
    override class func spec() {
        describe("parseSendArgs") {
            context("basic recipient") {
                it("sets the to field") {
                    expect(parseSendArgs(["alice@example.com"])?.to) == "alice@example.com"
                }
                it("defaults subject to empty") {
                    expect(parseSendArgs(["alice@example.com"])?.subject) == ""
                }
                it("defaults body to empty") {
                    expect(parseSendArgs(["alice@example.com"])?.body) == ""
                }
                it("defaults isDraft to false") {
                    expect(parseSendArgs(["alice@example.com"])?.isDraft) == false
                }
                it("defaults attachments to empty") {
                    expect(parseSendArgs(["alice@example.com"])?.attachments).to(beEmpty())
                }
            }

            context("multi-word recipient") {
                it("joins words before the first keyword as the recipient") {
                    expect(parseSendArgs(["Jane", "Doe", "subject", "Hi"])?.to) == "Jane Doe"
                }
                it("captures subject after recipient") {
                    expect(parseSendArgs(["Jane", "Doe", "subject", "Hi"])?.subject) == "Hi"
                }
            }

            context("subject keyword") {
                it("captures a multi-word subject") {
                    expect(parseSendArgs(["alice", "subject", "Hello", "World"])?.subject) == "Hello World"
                }
            }

            context("body keyword") {
                it("captures body text to end of args") {
                    expect(parseSendArgs(["alice", "subject", "Hi", "body", "Hello", "there"])?.body) == "Hello there"
                }
                it("captures body containing apostrophes when passed as a single token") {
                    let body = "I wanted you to see it first so you're not caught off guard."
                    expect(parseSendArgs(["alice", "body", body])?.body) == body
                }
                it("captures body containing newlines when passed as a single token") {
                    let body = "Line one.\nLine two.\nLine three."
                    expect(parseSendArgs(["alice", "body", body])?.body) == body
                }
                it("captures body containing em-dashes and asterisks when passed as a single token") {
                    let body = "Join us — I can forward details to anyone who's interested.\n*Nursery available."
                    expect(parseSendArgs(["alice", "body", body])?.body) == body
                }
            }

            context("cc keyword") {
                it("captures a single cc recipient") {
                    expect(parseSendArgs(["alice", "cc", "bob@example.com"])?.cc.first) == "bob@example.com"
                }
                it("captures a multi-word cc recipient") {
                    expect(parseSendArgs(["alice", "cc", "Bob", "Jones", "subject", "Hi"])?.cc.first) == "Bob Jones"
                }
                it("captures multiple cc entries from repeated keyword") {
                    expect(parseSendArgs(["alice", "cc", "bob", "cc", "carol"])?.cc) == ["bob", "carol"]
                }
            }

            context("attach keyword") {
                it("captures a single attachment path") {
                    expect(parseSendArgs(["alice", "attach", "/tmp/file.pdf"])?.attachments.first) == "/tmp/file.pdf"
                }
                it("captures multiple attachments from repeated keyword") {
                    expect(parseSendArgs(["alice", "attach", "/tmp/a.pdf", "attach", "/tmp/b.pdf"])?.attachments.count) == 2
                }
            }

            context("--draft flag") {
                it("sets isDraft when flag appears before recipient") {
                    expect(parseSendArgs(["--draft", "alice", "subject", "Hi"])?.isDraft) == true
                }
                it("sets isDraft when flag appears at end") {
                    expect(parseSendArgs(["alice", "subject", "Hi", "--draft"])?.isDraft) == true
                }
            }

            context("all keywords combined") {
                let args = ["alice", "cc", "bob", "subject", "Meeting",
                            "attach", "/tmp/doc.pdf", "body", "See attached"]
                it("captures to") { expect(parseSendArgs(args)?.to) == "alice" }
                it("captures cc") { expect(parseSendArgs(args)?.cc) == ["bob"] }
                it("captures subject") { expect(parseSendArgs(args)?.subject) == "Meeting" }
                it("captures attachment") { expect(parseSendArgs(args)?.attachments) == ["/tmp/doc.pdf"] }
                it("captures body") { expect(parseSendArgs(args)?.body) == "See attached" }
            }

            context("invalid input") {
                it("returns nil for empty args") {
                    expect(parseSendArgs([])).to(beNil())
                }
                it("returns nil when no recipient is present") {
                    expect(parseSendArgs(["subject", "Hi"])).to(beNil())
                }
            }
        }
    }
}
