// FindHandler.swift
// Handles the `mail find` command — searches recent messages by text.

import Foundation
import GetClearKit

public func handleFind(args: [String], client: any MailClient) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: MailCommandShapes.find, wrapError: MailError.badArguments
    )
    let query = parsed.identifiers[0]
    let emails = try await client.find(query: query, limit: 20)
    guard !emails.isEmpty else { return "No messages matching '\(query)'." }
    return emails.enumerated().map { i, email in
        let idx = ANSI.dim(String(i + 1).leftPad(3))
        let dateStr = ANSI.dim(formatDate(email.receivedAt).leftPad(8))
        let fromStr = ANSI.dim(String(email.from.prefix(24)).padding(toLength: 24, withPad: " ", startingAt: 0))
        return "  \(idx)  \(dateStr)  \(fromStr)  \(ANSI.bold(email.subject))"
    }.joined(separator: "\n")
}
