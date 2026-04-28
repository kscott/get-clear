import ContactKit
import GetClearKit

public func handleFind(args: [String], store: any ContactStore) async throws -> String {
    guard args.count > 1 else { throw ContactHandlerError.usage("provide a search query") }
    let query = args.dropFirst().joined(separator: " ")
    let all = try await store.fetchContacts(in: nil)
    let matched = matchContacts(query, in: all)
    guard !matched.isEmpty else { return "No contacts matching '\(query)'" }
    return matched.map { c in
        let nameStr  = c.name.isEmpty ? c.company : c.name
        let emailStr = c.emails.first.map { " <\($0.value)>" } ?? ""
        let compStr  = (!c.company.isEmpty && !c.name.isEmpty) ? " — \(c.company)" : ""
        return "  \(ANSI.bold(nameStr))\(emailStr)\(ANSI.dim(compStr))"
    }.joined(separator: "\n")
}
