// DoneHandler.swift

import GetClearKit

public func handleDone(args: [String], store: any ReminderStore) async throws -> String {
    guard args.count > 1 else { throw ReminderHandlerError("provide a reminder title") }
    let title    = args[1]
    let listName = args.count > 2 ? args[2] : nil
    let list     = try await resolvedList(named: listName, from: store)
    do {
        let item = try await store.complete(title: title, in: list)
        try? ActivityLog.write(tool: "reminders", cmd: "done", desc: title, container: item.list.title)
        return "Done: \(title)"
    } catch let err as ReminderStoreError {
        throw storeError(title: title, list: list, cmd: "done", err)
    }
}

private extension ReminderStore {
    func complete(title: String, in list: ReminderList?) async throws -> ReminderItem {
        let item = try await resolve(title: title, in: list)
        try await complete(identifier: item.identifier)
        return item
    }
}
