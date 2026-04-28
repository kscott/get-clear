import ContactKit
import GetClearKit

public func handleAdd(args: [String], store: any ContactStore) async throws -> String {
    guard args.count > 1 else { throw ContactHandlerError.usage("provide a contact name") }
    let name      = args[1]
    let remaining = Array(args.dropFirst(2))

    if remaining.first?.lowercased() == "to" {
        let groupName = remaining.dropFirst().joined(separator: " ")
        guard !groupName.isEmpty else { throw ContactHandlerError.usage("provide a group name after 'to'") }
        let contact = try await store.resolve(query: name)
        let group   = try await store.resolveGroup(named: groupName)
        try await store.add(identifier: contact.identifier, to: group)
        try? ActivityLog.write(tool: "contacts", cmd: "add", desc: "\(contact.name) → \(group.name)", container: group.name)
        return "Added \(contact.name) to \(group.name)"
    }

    var emails:  [String] = []
    var phones:  [String] = []
    var company: String?  = nil
    var i = 0
    while i < remaining.count {
        switch remaining[i].lowercased() {
        case "email" where i + 1 < remaining.count:
            emails.append(remaining[i + 1]); i += 2
        case "phone" where i + 1 < remaining.count:
            phones.append(remaining[i + 1]); i += 2
        case "company" where i + 1 < remaining.count:
            company = remaining[(i + 1)...].joined(separator: " "); i = remaining.count
        default:
            i += 1
        }
    }

    let draft  = ContactDraft(name: name, emails: emails, phones: phones, company: company)
    let saved  = try await store.add(draft)
    try? ActivityLog.write(tool: "contacts", cmd: "add", desc: name, container: nil)
    var parts = ["Added: \(saved.name)"]
    if !saved.emails.isEmpty { parts.append("email \(saved.emails.map(\.value).joined(separator: ", "))") }
    if !saved.phones.isEmpty { parts.append("phone \(saved.phones.map(\.value).joined(separator: ", "))") }
    if let c = saved.company.isEmpty ? nil : saved.company { parts.append("company \(c)") }
    return parts.joined(separator: " · ")
}
