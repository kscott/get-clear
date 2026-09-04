// SendHandlerSpec.swift
// Tests for TextLib handleSend.

import Foundation
import Testing
import TextLib

private final class SpyMessageSender: MessageSender {
    var lastQuery: String?
    var lastMessage: String?
    var shouldThrow: Error?
    var result = SendResult(displayName: "Alice Smith", address: "+15551234567")

    func send(to query: String, message: String) async throws -> SendResult {
        if let e = shouldThrow { throw e }
        lastQuery = query
        lastMessage = message
        return result
    }
}

@Suite("handleSend")
struct SendHandlerTests {
    @Suite("missing arguments")
    struct MissingArguments {
        @Test("throws when no message keyword follows the contact")
        func throwsWithoutMessage() async {
            let sender = SpyMessageSender()
            await #expect(throws: (any Error).self) {
                try await handleSend(args: ["send", "Alice"], sender: sender)
            }
        }

        @Test("throws when only the command is given")
        func throwsWithOnlyCommand() async {
            let sender = SpyMessageSender()
            await #expect(throws: (any Error).self) {
                try await handleSend(args: ["send"], sender: sender)
            }
        }

        @Test("throws when message is given with no value")
        func throwsWithEmptyMessage() async {
            let sender = SpyMessageSender()
            await #expect(throws: (any Error).self) {
                try await handleSend(args: ["send", "Alice", "message"], sender: sender)
            }
        }

        @Test("throws for a stray token before the message keyword")
        func throwsForStrayToken() async {
            let sender = SpyMessageSender()
            await #expect(throws: (any Error).self) {
                try await handleSend(args: ["send", "Alice", "hey", "message", "hi"], sender: sender)
            }
        }
    }

    @Suite("successful send")
    struct SuccessfulSend {
        @Test("passes the contact query to the sender")
        func passesContactQuery() async throws {
            let sender = SpyMessageSender()
            _ = try await handleSend(args: ["send", "Alice", "message", "hey there"], sender: sender)
            #expect(sender.lastQuery == "Alice")
        }

        @Test("joins a multi-word message after the keyword before passing to sender")
        func joinsMultiWordMessage() async throws {
            let sender = SpyMessageSender()
            _ = try await handleSend(args: ["send", "Alice", "message", "hey", "there"], sender: sender)
            #expect(sender.lastMessage == "hey there")
        }

        @Test("returns a confirmation containing the display name")
        func confirmationContainsDisplayName() async throws {
            let sender = SpyMessageSender()
            let result = try await handleSend(args: ["send", "Alice", "message", "hey"], sender: sender)
            #expect(result.contains("Alice Smith"))
        }

        @Test("returns a confirmation containing the address")
        func confirmationContainsAddress() async throws {
            let sender = SpyMessageSender()
            let result = try await handleSend(args: ["send", "Alice", "message", "hey"], sender: sender)
            #expect(result.contains("+15551234567"))
        }
    }

    @Suite("sender throws")
    struct SenderThrows {
        @Test("propagates notFound from the sender")
        func propagatesNotFound() async {
            let sender = SpyMessageSender()
            sender.shouldThrow = TextError.notFound("Nobody")
            await #expect(throws: TextError.notFound("Nobody")) {
                try await handleSend(args: ["send", "Nobody", "message", "hi"], sender: sender)
            }
        }

        @Test("propagates sendFailed from the sender")
        func propagatesSendFailed() async {
            let sender = SpyMessageSender()
            sender.shouldThrow = TextError.sendFailed("osascript error")
            await #expect(throws: TextError.sendFailed("osascript error")) {
                try await handleSend(args: ["send", "Alice", "message", "hi"], sender: sender)
            }
        }

        @Test("propagates ambiguous from the sender")
        func propagatesAmbiguous() async {
            let sender = SpyMessageSender()
            let message = "\"Alice\" matches multiple contacts — be more specific:\n  Alice Smith (+15551234567)\n  Alice Jones (alice@example.com)"
            sender.shouldThrow = TextError.ambiguous(message)
            await #expect(throws: TextError.ambiguous(message)) {
                try await handleSend(args: ["send", "Alice", "message", "hi"], sender: sender)
            }
        }
    }
}
