// ChangeHandler.swift

import GetClearKit

public func handleChange(args: [String], store: any ReminderStore) async throws -> String {
    let parsed: ParsedCommand
    do {
        parsed = try parseCommand(Array(args.dropFirst()), shape: ReminderCommandShapes.change)
    } catch let e as ArgumentError {
        throw ReminderHandlerError(e.errorDescription ?? "invalid arguments")
    }
    let title = parsed.identifiers[0]
    let allLists = try await store.fetchLists()
    let list = try resolvedList(named: parsed.values["list"], from: allLists)
    let item: ReminderItem
    do {
        item = try await store.resolve(title: title, in: list)
    } catch let err as ReminderStoreError {
        throw storeError(title: title, list: list, cmd: "change", err)
    }
    let opts = parseOptions(from: parsed)
    if !opts.date.isEmpty, opts.date.lowercased() != "none", parseDate(opts.date) == nil {
        throw ReminderHandlerError("couldn't parse date: \(opts.date)")
    }
    let changes: ReminderChanges
    do {
        changes = try parseReminderChanges(opts, existingItem: item)
    } catch ReminderChangeError.nothingToChange {
        throw ReminderHandlerError("nothing to change — specify a date, repeat, priority, note, url, or list")
    } catch let ReminderChangeError.unrecognizedRecurrence(s) {
        throw ReminderHandlerError("Unrecognised repeat: \"\(s)\"")
    } catch let ReminderChangeError.unrecognizedPriority(s) {
        throw ReminderHandlerError("unknown priority: \(s)")
    }
    try await store.update(identifier: item.identifier, changes: changes)
    var descs = changes.descriptions
    if case let .replaced(_, name) = changes.list { descs.append("moved to \(name)") }
    try? ActivityLog.write(tool: "reminders", cmd: "change", desc: title, container: item.list.title)
    return "Updated \"\(title)\": \(descs.joined(separator: ", "))"
}
