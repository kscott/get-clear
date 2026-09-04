import ContactKit
import GetClearKit

public func handleLists(args: [String], store: any ContactStore) async throws -> String {
    _ = try parseCommand(
        Array(args.dropFirst()), shape: ContactCommandShapes.lists, wrapError: ContactHandlerError.usage
    )
    let groups = try await store.fetchGroups()
    return groups.sorted { $0.name < $1.name }.map(\.name).joined(separator: "\n")
}

public func handleList(args: [String], store: any ContactStore) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: ContactCommandShapes.list, wrapError: ContactHandlerError.usage
    )
    let groupName = parsed.identifiers[0]
    let group = try await store.resolveGroup(named: groupName)
    let contacts = try await store.fetchContacts(in: group)
    return contacts
        .sorted { $0.displayName < $1.displayName }
        .map { c in
            let emailStr = c.emails.first.map { "<\($0.value)>" } ?? "(no email)"
            return "  \(ANSI.bold(c.displayName)) \(ANSI.dim(emailStr))"
        }
        .joined(separator: "\n")
}
