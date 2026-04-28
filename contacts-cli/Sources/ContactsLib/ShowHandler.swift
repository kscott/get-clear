import ContactKit

public func handleShow(args: [String], store: any ContactStore) async throws -> String {
    guard args.count > 1 else { throw ContactHandlerError.usage("provide a contact name") }
    let query = args.dropFirst().joined(separator: " ")
    let contact = try await store.resolve(query: query)
    return cardLines(for: contact).joined(separator: "\n")
}
