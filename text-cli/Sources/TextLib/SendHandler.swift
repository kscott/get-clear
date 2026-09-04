// SendHandler.swift
// Handles the `text send` command.

import GetClearKit

public func handleSend(args: [String], sender: any MessageSender) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: TextCommandShapes.send, wrapError: TextError.badArguments
    )
    let query = parsed.identifiers[0]
    // requiresTrailingText guarantees this is non-nil and non-empty — parseCommand throws first.
    let message = parsed.trailingText ?? ""
    let result = try await sender.send(to: query, message: message)
    try? ActivityLog.write(tool: "text", cmd: "send",
                           desc: "\(result.displayName): \(message)", container: nil)
    return formatSendConfirmation(result)
}

public func formatSendConfirmation(_ result: SendResult) -> String {
    "Sent to \(ANSI.bold(result.displayName)) \(ANSI.dim("(\(result.address))"))"
}
