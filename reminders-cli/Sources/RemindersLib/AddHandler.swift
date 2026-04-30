// AddHandler.swift

import Foundation
import GetClearKit

public func handleAdd(args: [String], store: any ReminderStore) async throws -> String {
    guard args.count > 1 else { throw ReminderHandlerError("provide a reminder title") }
    let title = args[1]
    let allLists = try await store.fetchLists()
    let (listName, rawOptions) = splitListAndOptions(
        from: Array(args.dropFirst(2)), calendarTitles: allLists.map(\.title)
    )
    let targetList: ReminderList = if let match = try resolvedList(named: listName, from: allLists) {
        match
    } else {
        try await store.defaultList()
    }
    let opts = parseOptions(rawOptions)
    let parsedDate = opts.date.isEmpty ? nil : parseDate(opts.date)
    let recurrenceSpec: RecurrenceSpec? = try {
        guard !opts.recurrence.isEmpty else { return nil }
        guard let spec = parseRecurrence(opts.recurrence) else {
            throw ReminderHandlerError("Unrecognised repeat: \"\(opts.recurrence)\"")
        }
        return spec
    }()
    let dueDateComponents = parsedDate.map(dateComponents(from:))
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
        priority: opts.priority, hasNote: !opts.note.isEmpty, url: opts.url
    )
}
