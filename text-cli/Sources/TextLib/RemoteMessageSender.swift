// RemoteMessageSender.swift
//
// A MessageSender that asks the Get Clear helper to send, so the Automation → Messages
// permission (and any contact lookup) belongs to Get Clear, not the terminal (spec 018).
// Pure: the transport is injected.

import GetClearKit

public struct RemoteMessageSender: MessageSender {
    private let caller: HelperCaller

    public init(transport: @escaping HelperTransport, appVersion: String) {
        caller = HelperCaller(
            tool: .text,
            appVersion: appVersion,
            transport: transport,
            decodeToolError: { try? HelperCoding.decode(TextError.self, from: $0) }
        )
    }

    public func send(to query: String, message: String) async throws -> SendResult {
        try await caller.call(MessageHelperRequest.send(query: query, message: message))
    }
}
