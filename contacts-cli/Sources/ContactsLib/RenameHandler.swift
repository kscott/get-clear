import ContactKit
import GetClearKit

public func handleRename(args: [String], store: any ContactStore) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: ContactCommandShapes.rename, wrapError: ContactHandlerError.usage
    )
    let query = parsed.identifiers[0]
    let newName = parsed.identifiers[1]
    let contact = try await store.resolve(query: query)
    try await store.rename(identifier: contact.identifier, to: newName)
    try? ActivityLog.write(tool: "contacts", cmd: "rename", desc: "\(contact.name) → \(newName)", container: nil)
    return "Renamed: \"\(contact.name)\" → \"\(newName)\""
}
