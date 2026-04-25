// MessageSender.swift
// Protocol for sending messages; abstraction boundary over Messages.app.

public struct SendResult: Equatable {
    public let displayName: String
    public let address: String
    public init(displayName: String, address: String) {
        self.displayName = displayName
        self.address     = address
    }
}

public protocol MessageSender {
    func send(to query: String, message: String) async throws -> SendResult
}
