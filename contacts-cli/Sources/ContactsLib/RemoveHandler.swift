import ContactKit
import GetClearKit

public func handleRemove(args: [String], store: any ContactStore) async throws -> String {
    guard args.count > 1 else { throw ContactHandlerError.usage("provide a contact name") }
    let query     = args[1]
    let remaining = Array(args.dropFirst(2))

    if remaining.first?.lowercased() == "from" {
        let groupName = remaining.dropFirst().joined(separator: " ")
        guard !groupName.isEmpty else { throw ContactHandlerError.usage("provide a group name after 'from'") }
        let contact = try await store.resolve(query: query)
        let group   = try await store.resolveGroup(named: groupName)
        try await store.remove(identifier: contact.identifier, from: group)
        try? ActivityLog.write(tool: "contacts", cmd: "remove", desc: "\(contact.name) → \(group.name)", container: group.name)
        return "Removed \(contact.name) from \(group.name)"
    }

    let contact = try await store.resolve(query: query)
    try await store.delete(identifier: contact.identifier)
    try? ActivityLog.write(tool: "contacts", cmd: "remove", desc: contact.name, container: nil)
    return "Removed: \(contact.name)"
}
