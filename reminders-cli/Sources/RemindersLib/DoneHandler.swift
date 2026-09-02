// DoneHandler.swift

import GetClearKit

public func handleDone(args: [String], store: any ReminderStore) async throws -> String {
    let parsed: ParsedCommand
    do {
        parsed = try parseCommand(Array(args.dropFirst()), shape: ReminderCommandShapes.done)
    } catch let e as ArgumentError {
        throw ReminderHandlerError(e.errorDescription ?? "invalid arguments")
    }
    let title = parsed.identifiers[0]
    let list = try await resolvedList(named: parsed.values["list"], from: store)
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
