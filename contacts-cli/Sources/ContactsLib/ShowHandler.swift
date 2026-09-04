import ContactKit
import GetClearKit

public func handleShow(args: [String], store: any ContactStore) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: ContactCommandShapes.show, wrapError: ContactHandlerError.usage
    )
    let contact = try await store.resolve(query: parsed.identifiers[0])
    return cardLines(for: contact).joined(separator: "\n")
}
