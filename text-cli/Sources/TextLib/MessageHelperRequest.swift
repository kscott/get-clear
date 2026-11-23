// MessageHelperRequest.swift
//
// One case per MessageSender method: what a command asks the Get Clear helper to do with
// Messages (spec 018). Adding a method means adding a case here, in RemoteMessageSender,
// and in MessageDispatch.

import GetClearKit

public enum MessageHelperRequest: Codable, Equatable, Sendable {
    case send(query: String, message: String)

    /// Messages always; Contacts only when the recipient is a name to look up, so texting a
    /// phone number or email never prompts for Contacts (FR-004).
    public var requiredAccess: [StoreKind] {
        switch self {
        case let .send(query, _):
            requiresContactLookup(query) ? [.contacts, .messages] : [.messages]
        }
    }
}
