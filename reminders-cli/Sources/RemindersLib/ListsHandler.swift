// ListsHandler.swift

import GetClearKit

public func handleLists(args: [String], store: any ReminderStore) async throws -> String {
    _ = try parseCommand(
        Array(args.dropFirst()), shape: ReminderCommandShapes.lists, wrapError: ReminderHandlerError.init
    )
    let lists = try await store.fetchLists()
    return lists.map(\.title).sorted().joined(separator: "\n")
}
