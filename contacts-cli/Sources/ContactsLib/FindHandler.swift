import ContactKit
import GetClearKit

public func handleFind(args: [String], store: any ContactStore) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: ContactCommandShapes.find, wrapError: ContactHandlerError.usage
    )
    let query = parsed.identifiers[0]
    let all = try await store.fetchContacts(in: nil)
    let matched = matchContacts(query, in: all)
    guard !matched.isEmpty else { return "No contacts matching '\(query)'" }
    return matched.map { c in
        let emailStr = c.emails.first.map { " <\($0.value)>" } ?? ""
        let compStr = (!c.company.isEmpty && !c.name.isEmpty) ? " — \(c.company)" : ""
        return "  \(ANSI.bold(c.displayName))\(emailStr)\(ANSI.dim(compStr))"
    }.joined(separator: "\n")
}
