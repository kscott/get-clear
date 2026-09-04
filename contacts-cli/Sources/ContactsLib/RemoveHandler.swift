import ContactKit
import GetClearKit

public func handleRemove(args: [String], store: any ContactStore) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: ContactCommandShapes.remove, wrapError: ContactHandlerError.usage
    )
    let query = parsed.identifiers[0]

    if let groupName = parsed.values["from"] {
        let contact = try await store.resolve(query: query)
        let group = try await store.resolveGroup(named: groupName)
        try await store.remove(identifier: contact.identifier, from: group)
        try? ActivityLog.write(tool: "contacts", cmd: "remove", desc: "\(contact.name) → \(group.name)", container: group.name)
        return "Removed \(contact.name) from \(group.name)"
    }

    let contact = try await store.resolve(query: query)
    try await store.delete(identifier: contact.identifier)
    try? ActivityLog.write(tool: "contacts", cmd: "remove", desc: contact.name, container: nil)
    return "Removed: \(contact.name)"
}
