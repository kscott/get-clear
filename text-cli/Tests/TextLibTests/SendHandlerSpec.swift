// SendHandlerSpec.swift

import Quick
import Nimble
import Foundation
import TextLib

final class SpyMessageSender: MessageSender {
    var sentRecipient: String?
    var sentMessage: String?
    var shouldThrow: Error?

    func send(to recipient: String, message: String) async throws {
        if let e = shouldThrow { throw e }
        sentRecipient = recipient
        sentMessage   = message
    }
}

private func makeContacts() -> [MessageContact] {
    [MessageContact(name: "Alice Smith", phones: ["+15551234567"], emails: [])]
}

final class SendHandlerSpec: AsyncSpec {
    override class func spec() {

        describe("handleSend") {

            context("missing arguments") {
                it("throws when fewer than 3 args are given") {
                    let sender = SpyMessageSender()
                    do {
                        _ = try await handleSend(args: ["send", "Alice"], contacts: [], sender: sender)
                        fail("expected TextError")
                    } catch is TextError { }
                }
            }

            context("contact not found") {
                it("throws TextError.notFound when query matches no contact") {
                    let sender = SpyMessageSender()
                    do {
                        _ = try await handleSend(args: ["send", "Nobody", "hello"], contacts: [], sender: sender)
                        fail("expected TextError.notFound")
                    } catch TextError.notFound(let q) {
                        expect(q) == "Nobody"
                    }
                }
            }

            context("successful send") {
                it("calls sender with normalized phone number") {
                    let sender = SpyMessageSender()
                    _ = try await handleSend(args: ["send", "Alice", "hey there"],
                                             contacts: makeContacts(), sender: sender)
                    expect(sender.sentRecipient) == "+15551234567"
                }
                it("calls sender with the full message") {
                    let sender = SpyMessageSender()
                    _ = try await handleSend(args: ["send", "Alice", "hey", "there"],
                                             contacts: makeContacts(), sender: sender)
                    expect(sender.sentMessage) == "hey there"
                }
                it("returns a confirmation string containing the contact name") {
                    let sender = SpyMessageSender()
                    let result = try await handleSend(args: ["send", "Alice", "hey"],
                                                      contacts: makeContacts(), sender: sender)
                    expect(result).to(contain("Alice Smith"))
                }
            }

            context("send failure") {
                it("propagates the error from the sender") {
                    let sender = SpyMessageSender()
                    sender.shouldThrow = TextError.sendFailed("osascript error")
                    do {
                        _ = try await handleSend(args: ["send", "Alice", "hey"],
                                                 contacts: makeContacts(), sender: sender)
                        fail("expected TextError.sendFailed")
                    } catch TextError.sendFailed(let msg) {
                        expect(msg) == "osascript error"
                    }
                }
            }
        }
    }
}
