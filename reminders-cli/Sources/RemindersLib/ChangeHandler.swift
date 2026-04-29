// ChangeHandler.swift

import GetClearKit

public func handleChange(args: [String], store: any ReminderStore) async throws -> String {
    guard args.count > 1 else { throw ReminderHandlerError("provide a reminder title") }
    let title    = args[1]
    let allLists = try await store.fetchLists()
    let (listName, rawOptions) = splitListAndOptions(
        from: Array(args.dropFirst(2)), calendarTitles: allLists.map(\.title))
    let list = try resolvedList(named: listName, from: allLists)
    let item: ReminderItem
    do {
        item = try await store.resolve(title: title, in: list)
    } catch let err as ReminderStoreError {
        throw storeError(title: title, list: list, cmd: "change", err)
    }
    let opts = parseOptions(rawOptions)
    let changes: ReminderChanges
    do {
        changes = try parseReminderChanges(opts, existingItem: item)
    } catch ReminderChangeError.nothingToChange {
        throw ReminderHandlerError("nothing to change — specify a date, repeat, priority, note, url, or list")
    } catch ReminderChangeError.unrecognizedRecurrence(let s) {
        throw ReminderHandlerError("Unrecognised repeat: \"\(s)\"")
    }
    try await store.update(identifier: item.identifier, changes: changes)
    var descs = changes.descriptions
    if case .replaced(_, let name) = changes.list { descs.append("moved to \(name)") }
    try? ActivityLog.write(tool: "reminders", cmd: "change", desc: title, container: item.list.title)
    return "Updated \"\(title)\": \(descs.joined(separator: ", "))"
}
