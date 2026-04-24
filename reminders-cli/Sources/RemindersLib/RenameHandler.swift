// RenameHandler.swift

import GetClearKit

public func handleRename(args: [String], store: any ReminderStore) async throws -> String {
    guard args.count > 2 else { throw ReminderHandlerError("provide existing title and new title") }
    let oldTitle = args[1]
    let newTitle = args[2]
    let listName = args.count > 3 ? args[3] : nil
    let list     = try await resolvedList(named: listName, from: store)
    do {
        let item = try await store.resolve(title: oldTitle, in: list, cmd: "rename")
        try await store.rename(identifier: item.identifier, to: newTitle)
        try? ActivityLog.write(tool: "reminders", cmd: "rename", desc: "\(oldTitle) → \(newTitle)", container: item.list.title)
        return "Renamed: \"\(oldTitle)\" → \"\(newTitle)\""
    } catch let err as ReminderStoreError {
        throw storeError(title: oldTitle, list: list, cmd: "rename", err)
    }
}
