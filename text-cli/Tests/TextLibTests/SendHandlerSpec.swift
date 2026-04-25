// SendHandlerSpec.swift
// Tests for TextLib handleSend.

import Quick
import Nimble
import Foundation
import TextLib

private final class SpyMessageSender: MessageSender {
    var lastQuery:   String?
    var lastMessage: String?
    var shouldThrow: Error?
    var result = SendResult(displayName: "Alice Smith", address: "+15551234567")

    func send(to query: String, message: String) async throws -> SendResult {
        if let e = shouldThrow { throw e }
        lastQuery   = query
        lastMessage = message
        return result
    }
}

final class SendHandlerSpec: AsyncSpec {
    override class func spec() {

        describe("handleSend") {

            context("missing arguments") {
                it("throws when no message follows the contact") {
                    let sender = SpyMessageSender()
                    await expect {
                        try await handleSend(args: ["send", "Alice"], sender: sender)
                    }.to(throwError())
                }
                it("throws when only the command is given") {
                    let sender = SpyMessageSender()
                    await expect {
                        try await handleSend(args: ["send"], sender: sender)
                    }.to(throwError())
                }
            }

            context("successful send") {
                it("passes the contact query to the sender") {
                    let sender = SpyMessageSender()
                    _ = try await handleSend(args: ["send", "Alice", "hey there"], sender: sender)
                    expect(sender.lastQuery) == "Alice"
                }
                it("joins multi-word message before passing to sender") {
                    let sender = SpyMessageSender()
                    _ = try await handleSend(args: ["send", "Alice", "hey", "there"], sender: sender)
                    expect(sender.lastMessage) == "hey there"
                }
                it("returns a confirmation containing the display name") {
                    let sender = SpyMessageSender()
                    let result = try await handleSend(args: ["send", "Alice", "hey"], sender: sender)
                    expect(result).to(contain("Alice Smith"))
                }
                it("returns a confirmation containing the address") {
                    let sender = SpyMessageSender()
                    let result = try await handleSend(args: ["send", "Alice", "hey"], sender: sender)
                    expect(result).to(contain("+15551234567"))
                }
            }

            context("sender throws") {
                it("propagates notFound from the sender") {
                    let sender = SpyMessageSender()
                    sender.shouldThrow = TextError.notFound("Nobody")
                    await expect {
                        try await handleSend(args: ["send", "Nobody", "hi"], sender: sender)
                    }.to(throwError(TextError.notFound("Nobody")))
                }
                it("propagates sendFailed from the sender") {
                    let sender = SpyMessageSender()
                    sender.shouldThrow = TextError.sendFailed("osascript error")
                    await expect {
                        try await handleSend(args: ["send", "Alice", "hi"], sender: sender)
                    }.to(throwError(TextError.sendFailed("osascript error")))
                }
                it("propagates ambiguous from the sender") {
                    let sender = SpyMessageSender()
                    sender.shouldThrow = TextError.ambiguous("\"Alice\" matches multiple contacts — be more specific:\n  Alice Smith (+15551234567)\n  Alice Jones (alice@example.com)")
                    await expect {
                        try await handleSend(args: ["send", "Alice", "hi"], sender: sender)
                    }.to(throwError(TextError.ambiguous("\"Alice\" matches multiple contacts — be more specific:\n  Alice Smith (+15551234567)\n  Alice Jones (alice@example.com)")))
                }
            }
        }
    }
}
