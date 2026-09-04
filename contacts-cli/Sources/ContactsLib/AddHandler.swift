import ContactKit
import GetClearKit

public func handleAdd(args: [String], store: any ContactStore) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: ContactCommandShapes.add, wrapError: ContactHandlerError.usage
    )
    let name = parsed.identifiers[0]

    if let groupName = parsed.values["to"] {
        guard parsed.values["email"] == nil, parsed.values["phone"] == nil, parsed.values["company"] == nil else {
            throw ContactHandlerError.usage("can't combine 'to' with email, phone, or company")
        }
        let contact = try await store.resolve(query: name)
        let group = try await store.resolveGroup(named: groupName)
        try await store.add(identifier: contact.identifier, to: group)
        try? ActivityLog.write(tool: "contacts", cmd: "add", desc: "\(contact.name) → \(group.name)", container: group.name)
        return "Added \(contact.name) to \(group.name)"
    }

    let draft = ContactDraft(
        name: name,
        emails: parsed.values["email"].map { [$0] } ?? [],
        phones: parsed.values["phone"].map { [$0] } ?? [],
        company: parsed.values["company"]
    )
    let saved = try await store.add(draft)
    try? ActivityLog.write(tool: "contacts", cmd: "add", desc: name, container: nil)
    var parts = ["Added: \(saved.name)"]
    if !saved.emails.isEmpty { parts.append("email \(saved.emails.map(\.value).joined(separator: ", "))") }
    if !saved.phones.isEmpty { parts.append("phone \(saved.phones.map(\.value).joined(separator: ", "))") }
    if !saved.company.isEmpty { parts.append("company \(saved.company)") }
    return parts.joined(separator: " · ")
}
