// MessageHelperRequest.swift
//
// One case per MessageSender method: what a command asks the Get Clear helper to do with
// Messages (spec 018). Adding a method means adding a case here, in RemoteMessageSender,
// and in MessageDispatch.

public enum MessageHelperRequest: Codable, Equatable, Sendable {
    case send(query: String, message: String)
}
