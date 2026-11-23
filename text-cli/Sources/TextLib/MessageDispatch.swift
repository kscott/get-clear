// MessageDispatch.swift
//
// The helper side of RemoteMessageSender: decodes one MessageHelperRequest, sends through the
// real sender, and answers with the encoded result or error (spec 018). Pure over the
// MessageSender protocol, so tests run it against a spy.

import Foundation
import GetClearKit

public func dispatchMessageRequest(_ request: Data, to sender: any MessageSender) async -> HelperReply {
    await HelperResponder.respond(
        to: request,
        as: MessageHelperRequest.self,
        encodeToolError: { ($0 as? TextError).flatMap { try? HelperCoding.encode($0) } },
        handle: { request in
            switch request {
            case let .send(query, message):
                try await HelperCoding.encode(sender.send(to: query, message: message))
            }
        }
    )
}
