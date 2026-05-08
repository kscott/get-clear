// SendHandler.swift
// Handles the `text send` command.

import GetClearKit

public func handleSend(args: [String], sender: any MessageSender) async throws -> String {
    guard args.count > 2 else { throw TextError.badArguments("provide a contact and message") }
    let query = args[1]
    let message = args.dropFirst(2).joined(separator: " ")
    let result = try await sender.send(to: query, message: message)
    try? ActivityLog.write(tool: "text", cmd: "send",
                           desc: "\(result.displayName): \(message)", container: nil)
    return formatSendConfirmation(result)
}

public func formatSendConfirmation(_ result: SendResult) -> String {
    "Sent to \(ANSI.bold(result.displayName)) \(ANSI.dim("(\(result.address))"))"
}
