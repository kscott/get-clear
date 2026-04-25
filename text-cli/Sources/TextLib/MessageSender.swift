// MessageSender.swift

public protocol MessageSender {
    func send(to recipient: String, message: String) async throws
}
