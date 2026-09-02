// RemoveHandler.swift

import GetClearKit

public func handleRemove(args: [String], store: any ReminderStore) async throws -> String {
    let parsed: ParsedCommand
    do {
        parsed = try parseCommand(Array(args.dropFirst()), shape: ReminderCommandShapes.remove)
    } catch let e as ArgumentError {
        throw ReminderHandlerError(e.errorDescription ?? "invalid arguments")
    }
    let title = parsed.identifiers[0]
    let list = try await resolvedList(named: parsed.values["list"], from: store)
    do {
        let item = try await store.resolve(title: title, in: list)
        try await store.delete(identifier: item.identifier)
        try? ActivityLog.write(tool: "reminders", cmd: "remove", desc: title, container: item.list.title)
        return "Removed: \(title)"
    } catch let err as ReminderStoreError {
        throw storeError(title: title, list: list, cmd: "remove", err)
    }
}
