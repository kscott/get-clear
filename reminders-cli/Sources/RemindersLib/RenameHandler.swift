// RenameHandler.swift

import GetClearKit

public func handleRename(args: [String], store: any ReminderStore) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: ReminderCommandShapes.rename, wrapError: ReminderHandlerError.init
    )
    let oldTitle = parsed.identifiers[0]
    let newTitle = parsed.identifiers[1]
    let list = try await resolvedList(named: parsed.values["list"], from: store)
    do {
        let item = try await store.resolve(title: oldTitle, in: list)
        try await store.rename(identifier: item.identifier, to: newTitle)
        try? ActivityLog.write(tool: "reminders", cmd: "rename", desc: "\(oldTitle) → \(newTitle)", container: item.list.title)
        return "Renamed: \"\(oldTitle)\" → \"\(newTitle)\""
    } catch let err as ReminderStoreError {
        throw storeError(title: oldTitle, list: list, cmd: "rename", err)
    }
}
