// AddHandler.swift

import Foundation
import GetClearKit

public func handleAdd(args: [String], store: any ReminderStore) async throws -> String {
    guard args.count > 1 else { throw ReminderHandlerError("provide a reminder title") }
    let title    = args[1]
    let allLists = try await store.fetchLists()
    let (listName, rawOptions) = splitListAndOptions(
        from: Array(args.dropFirst(2)), calendarTitles: allLists.map(\.title))
    let targetList: ReminderList
    if let name = listName {
        guard let match = allLists.first(where: { $0.title == name }) else {
            throw ReminderHandlerError("List not found: \(name)")
        }
        targetList = match
    } else {
        targetList = try await store.defaultList()
    }
    let opts = parseOptions(rawOptions)
    let parsedDate = opts.date.isEmpty ? nil : parseDate(opts.date)
    let recurrenceSpec: RecurrenceSpec?
    if opts.recurrence.isEmpty {
        recurrenceSpec = nil
    } else {
        guard let spec = parseRecurrence(opts.recurrence) else {
            throw ReminderHandlerError("Unrecognised repeat: \"\(opts.recurrence)\"")
        }
        recurrenceSpec = spec
    }
    let dueDateComponents: DateComponents?
    if let pd = parsedDate {
        let fields: Set<Calendar.Component> = pd.hasTime
            ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
        dueDateComponents = Calendar.current.dateComponents(fields, from: pd.date)
    } else {
        dueDateComponents = nil
    }
    let item = ReminderItem(
        title: title, list: targetList,
        dueDateComponents: dueDateComponents,
        recurrenceSpec: recurrenceSpec,
        priority: parsePriority(opts.priority) ?? 0,
        notes: opts.note.isEmpty ? nil : opts.note,
        url: opts.url.isEmpty ? nil : URL(string: opts.url)
    )
    let saved = try await store.add(item)
    try? ActivityLog.write(tool: "reminders", cmd: "add", desc: title, container: saved.list.title)
    return formatAddConfirmation(
        title: title, list: saved.list.title,
        date: parsedDate, recurrence: recurrenceSpec,
        priority: opts.priority, hasNote: !opts.note.isEmpty, url: opts.url)
}
