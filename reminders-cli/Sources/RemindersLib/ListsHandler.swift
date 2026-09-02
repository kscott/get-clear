// ListsHandler.swift

import GetClearKit

public func handleLists(args: [String], store: any ReminderStore) async throws -> String {
    do {
        _ = try parseCommand(Array(args.dropFirst()), shape: ReminderCommandShapes.lists)
    } catch let e as ArgumentError {
        throw ReminderHandlerError(e.errorDescription ?? "invalid arguments")
    }
    let lists = try await store.fetchLists()
    return lists.map(\.title).sorted().joined(separator: "\n")
}
