// MessageDispatchSpec.swift
//
// Tests for TextLib dispatchMessageRequest — how the helper side answers failures.
// Successful sends are covered end to end in RemoteMessageSenderSpec.

import Foundation
import GetClearKit
import Testing
import TextLib

private struct AppleScriptLikeError: LocalizedError {
    var errorDescription: String? {
        "Messages got an error: Can’t get buddy id."
    }
}

private struct FailingSender: MessageSender {
    let error: Error

    func send(to _: String, message _: String) async throws -> SendResult {
        throw error
    }
}

private let sendRequest = MessageHelperRequest.send(query: "Alice", message: "hi")

@Suite("dispatchMessageRequest failures")
struct MessageDispatchTests {
    @Test("a TextError is answered as a typed tool error")
    func typedError() async throws {
        let expected = try HelperReply.failure(.toolError(HelperCoding.encode(TextError.ambiguous("Alice matches 2 contacts"))))
        let answer = try await dispatchMessageRequest(
            HelperCoding.encode(sendRequest),
            to: FailingSender(error: TextError.ambiguous("Alice matches 2 contacts"))
        )
        #expect(answer == expected)
    }

    @Test("any other error is answered with its exact description")
    func otherError() async throws {
        let answer = try await dispatchMessageRequest(HelperCoding.encode(sendRequest), to: FailingSender(error: AppleScriptLikeError()))
        #expect(answer == .failure(.storeError(message: "Messages got an error: Can’t get buddy id.")))
    }

    @Test("a request that isn't a text request is answered as a bad request")
    func badRequest() async {
        let answer = await dispatchMessageRequest(Data("{\"nope\":{}}".utf8), to: FailingSender(error: AppleScriptLikeError()))
        #expect(answer.isBadRequest)
    }
}

private extension HelperReply {
    var isBadRequest: Bool {
        if case .failure(.badRequest) = self { return true }
        return false
    }
}
