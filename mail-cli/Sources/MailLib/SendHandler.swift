// SendHandler.swift
// Handles the `mail send` and `mail draft` commands — compose is shared, only the final
// action (send vs. saveDraft) and confirmation wording differ.

import ContactKit
import Foundation
import GetClearKit

public func handleSend(
    args: [String], config: MailConfig, client: any MailClient, contactStore: any ContactStore
) async throws -> String {
    try await compose(args: args, config: config, client: client, contactStore: contactStore, isDraft: false)
}

public func handleDraft(
    args: [String], config: MailConfig, client: any MailClient, contactStore: any ContactStore
) async throws -> String {
    try await compose(args: args, config: config, client: client, contactStore: contactStore, isDraft: true)
}

/// send and draft share one shape (MailCommandShapes.draft == .send) — no need to pass which.
private func compose(
    args: [String], config: MailConfig, client: any MailClient, contactStore: any ContactStore, isDraft: Bool
) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: MailCommandShapes.send, wrapError: MailError.badArguments
    )
    let msg = composeMessage(from: parsed)

    guard let identity = config.identity(for: config.defaultFrom) else {
        throw MailError.noMatchingIdentity(config.defaultFrom)
    }

    let allRecipients = [msg.to] + msg.cc
    let needsLookup = allRecipients.contains(where: requiresContactLookup)
    let contacts = needsLookup ? try await contactStore.contacts() : []
    let groups = needsLookup ? try await loadGroupMembers(from: contactStore) : [:]

    let (toAddrs, ccAddrs) = buildRecipients(to: [msg.to], cc: msg.cc,
                                             groups: groups, contacts: contacts)
    guard !toAddrs.isEmpty else {
        throw MailError.sendFailed("Could not resolve recipient: \(msg.to)")
    }

    let email = OutboundEmail(from: identity, to: toAddrs, cc: ccAddrs,
                              subject: msg.subject, body: msg.body,
                              attachmentPaths: msg.attachments)

    let toStr = toAddrs.map(\.formatted).joined(separator: ", ")
    if isDraft {
        try await client.saveDraft(email)
        try? ActivityLog.write(tool: "mail", cmd: "draft", desc: "draft: \(toStr)", container: nil)
        return formatSendConfirmation(to: toStr, cc: ccAddrs, subject: msg.subject, isDraft: true)
    }

    try await client.send(email)
    let logDesc = msg.subject.isEmpty ? toStr : "\(toStr) Re: \(msg.subject)"
    try? ActivityLog.write(tool: "mail", cmd: "send", desc: logDesc, container: nil)
    return formatSendConfirmation(to: toStr, cc: ccAddrs, subject: msg.subject, isDraft: false)
}

/// Expand group membership from a ContactStore into the map RecipientResolver expects.
public func loadGroupMembers(from store: any ContactStore) async throws -> [String: [AddressEntry]] {
    let groups = try await store.fetchGroups()
    return try await withThrowingTaskGroup(of: (String, [AddressEntry]).self) { taskGroup in
        for group in groups {
            taskGroup.addTask {
                let members = try await store.fetchContacts(in: group)
                let addrs = members.compactMap { c -> AddressEntry? in
                    guard let email = c.emails.first?.value else { return nil }
                    return AddressEntry(name: c.name, email: email)
                }
                return (group.name, addrs)
            }
        }
        var result: [String: [AddressEntry]] = [:]
        for try await (name, addrs) in taskGroup where !addrs.isEmpty {
            result[name] = addrs
        }
        return result
    }
}
