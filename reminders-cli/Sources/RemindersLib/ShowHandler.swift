// ShowHandler.swift

import GetClearKit

public func handleShow(args: [String], store: any ReminderStore) async throws -> String {
    let parsed: ParsedCommand
    do {
        parsed = try parseCommand(Array(args.dropFirst()), shape: ReminderCommandShapes.show)
    } catch let e as ArgumentError {
        throw ReminderHandlerError(e.errorDescription ?? "invalid arguments")
    }
    let title = parsed.identifiers[0]
    let list = try await resolvedList(named: parsed.values["list"], from: store)
    do {
        let item = try await store.resolve(title: title, in: list)
        return formatShow(item: item)
    } catch let err as ReminderStoreError {
        throw storeError(title: title, list: list, cmd: "show", err)
    }
}
