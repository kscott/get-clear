import ContactKit
import GetClearKit

public func handleChange(args: [String], store: any ContactStore) async throws -> String {
    guard args.count >= 2 else { throw ContactHandlerError.usage("provide a contact name") }
    let query = args[1]
    let changeArgs = Array(args.dropFirst(2))
    let changes = try parseContactChanges(changeArgs)
    let contact = try await store.resolve(query: query)
    try await store.update(identifier: contact.identifier, changes: changes)
    try? ActivityLog.write(tool: "contacts", cmd: "change", desc: contact.name, container: nil)
    return "Updated \"\(contact.name)\": \(describeChanges(changes))"
}

private func describeChanges(_ changes: ContactChanges) -> String {
    var parts: [String] = []
    appendDescription(changes.email, label: "email", into: &parts)
    appendDescription(changes.phone, label: "phone", into: &parts)
    appendDescription(changes.company, label: "company", into: &parts)
    return parts.joined(separator: ", ")
}

private func appendDescription(_ change: ValueChange<String>, label: String, into parts: inout [String]) {
    switch change {
    case .unchanged: break
    case .cleared: parts.append("\(label) cleared")
    case let .added(v): parts.append("\(label) +\(v)")
    case let .removed(v): parts.append("\(label) -\(v)")
    case let .replaced(f, t): parts.append("\(label) \(f) → \(t)")
    }
}
