// ShowHandler.swift

import GetClearKit

public func handleShow(args: [String], store: any ReminderStore) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: ReminderCommandShapes.show, wrapError: ReminderHandlerError.init
    )
    let title = parsed.identifiers[0]
    let list = try await resolvedList(named: parsed.values["list"], from: store)
    do {
        let item = try await store.resolve(title: title, in: list)
        return formatShow(item: item)
    } catch let err as ReminderStoreError {
        throw storeError(title: title, list: list, cmd: "show", err)
    }
}
