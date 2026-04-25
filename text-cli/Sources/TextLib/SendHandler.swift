// SendHandler.swift

import GetClearKit

public func handleSend(
    args: [String],
    contacts: [MessageContact],
    sender: any MessageSender
) async throws -> String {
    guard args.count > 2 else { throw TextError.badArguments("provide a contact and message") }
    let query   = args[1]
    let message = args.dropFirst(2).joined(separator: " ")

    guard let target = resolveSendTarget(query, contacts: contacts) else {
        throw TextError.notFound(query)
    }
    try await sender.send(to: target.address, message: message)
    try? ActivityLog.write(tool: "text", cmd: "send", desc: "\(target.name): \(message)", container: nil)
    return "Sent to \(ANSI.bold(target.name)) \(ANSI.dim("(\(target.address))"))"
}
