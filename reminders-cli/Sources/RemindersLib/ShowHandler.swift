// ShowHandler.swift

public func handleShow(args: [String], store: any ReminderStore) async throws -> String {
    guard args.count > 1 else { throw ReminderHandlerError("provide a reminder title") }
    let title = args[1]
    let listName = args.count > 2 ? args[2] : nil
    let list = try await resolvedList(named: listName, from: store)
    do {
        let item = try await store.resolve(title: title, in: list)
        return formatShow(item: item)
    } catch let err as ReminderStoreError {
        throw storeError(title: title, list: list, cmd: "show", err)
    }
}
