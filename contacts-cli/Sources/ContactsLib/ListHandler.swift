import ContactKit
import GetClearKit

public func handleLists(store: any ContactStore) async throws -> String {
    let groups = try await store.fetchGroups()
    return groups.sorted { $0.name < $1.name }.map(\.name).joined(separator: "\n")
}

public func handleList(args: [String], store: any ContactStore) async throws -> String {
    guard args.count > 1 else { throw ContactHandlerError.usage("provide a group name") }
    let groupName = args.dropFirst().joined(separator: " ")
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
