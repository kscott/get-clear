// RemoteMessageSenderSpec.swift
//
// Tests for TextLib RemoteMessageSender, wired to dispatchMessageRequest and a spy sender
// through a loopback transport — no XPC involved.

import Foundation
import GetClearKit
import Testing
import TextLib

/// @unchecked Sendable: each @Test builds its own spy; none is shared across tests.
private final class SpySender: MessageSender, @unchecked Sendable {
    var sent: [(query: String, message: String)] = []
    var failure: TextError?

    func send(to query: String, message: String) async throws -> SendResult {
        if let failure { throw failure }
        sent.append((query, message))
        return SendResult(displayName: "Alice Chen", address: "+15551234567")
    }
}

private func remote(_ spy: SpySender) -> RemoteMessageSender {
    RemoteMessageSender(transport: { await dispatchMessageRequest($0.request, to: spy) }, appVersion: "1.4.0")
}

@Suite("RemoteMessageSender")
struct RemoteMessageSenderTests {
    @Test("send delivers the recipient and message to the helper's sender")
    func delivers() async throws {
        let spy = SpySender()
        _ = try await remote(spy).send(to: "Alice", message: "hi")
        #expect(spy.sent.map { "\($0.query): \($0.message)" } == ["Alice: hi"])
    }

    @Test("send returns who the helper's sender delivered to")
    func returnsResult() async throws {
        #expect(try await remote(SpySender()).send(to: "Alice", message: "hi")
            == SendResult(displayName: "Alice Chen", address: "+15551234567"))
    }

    @Test("a text error from the helper comes back as the same typed value")
    func typedError() async {
        let spy = SpySender()
        spy.failure = .notFound("Zed")
        await #expect(throws: TextError.notFound("Zed")) {
            _ = try await remote(spy).send(to: "Zed", message: "hi")
        }
    }
}
