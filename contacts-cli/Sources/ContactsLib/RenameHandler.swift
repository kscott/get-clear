import ContactKit
import GetClearKit

public func handleRename(args: [String], store: any ContactStore) async throws -> String {
    guard args.count >= 3 else { throw ContactHandlerError.usage("provide existing name and new name") }
    let query   = args[1]
    let newName = args[2]
    let contact = try await store.resolve(query: query)
    try await store.rename(identifier: contact.identifier, to: newName)
    try? ActivityLog.write(tool: "contacts", cmd: "rename", desc: "\(contact.name) → \(newName)", container: nil)
    return "Renamed: \"\(contact.name)\" → \"\(newName)\""
}
