// RemoveHandler.swift

import GetClearKit

public func handleRemove(args: [String], store: any ReminderStore) async throws -> String {
    guard args.count > 1 else { throw ReminderHandlerError("provide a reminder title") }
    let title    = args[1]
    let listName = args.count > 2 ? args[2] : nil
    let list     = try await resolvedList(named: listName, from: store)
    do {
        let item = try await store.resolve(title: title, in: list)
        try await store.delete(identifier: item.identifier)
        try? ActivityLog.write(tool: "reminders", cmd: "remove", desc: title, container: item.list.title)
        return "Removed: \(title)"
    } catch let err as ReminderStoreError {
        throw storeError(title: title, list: list, cmd: "remove", err)
    }
}
