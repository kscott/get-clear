// AddHandler.swift

import Foundation
import GetClearKit

public func handleAdd(args: [String], store: any ReminderStore) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: ReminderCommandShapes.add, wrapError: ReminderHandlerError.init
    )
    let title = parsed.identifiers[0]
    let allLists = try await store.fetchLists()
    let opts = parseOptions(from: parsed)
    let targetList: ReminderList = if let match = try resolvedList(named: parsed.values["list"], from: allLists) {
        match
    } else {
        try await store.defaultList()
    }
    let parsedDate: ParsedDate?
    if opts.date.isEmpty {
        parsedDate = nil
    } else if let d = parseDate(opts.date) {
        parsedDate = d
    } else {
        throw ReminderHandlerError("couldn't parse date: \(opts.date)")
    }
    let recurrenceSpec: RecurrenceSpec? = try {
        guard !opts.recurrence.isEmpty else { return nil }
        guard let spec = parseRecurrence(opts.recurrence) else {
            throw ReminderHandlerError("Unrecognised repeat: \"\(opts.recurrence)\"")
        }
        return spec
    }()
    let priorityValue: Int
    if opts.priority.isEmpty {
        priorityValue = 0
    } else if let p = parsePriority(opts.priority) {
        priorityValue = p
    } else {
        throw ReminderHandlerError("unknown priority: \(opts.priority)")
    }
    let dueDateComponents = parsedDate.map(dateComponents(from:))
    let item = ReminderItem(
        title: title, list: targetList,
        dueDateComponents: dueDateComponents,
        recurrenceSpec: recurrenceSpec,
        priority: priorityValue,
        notes: opts.note.isEmpty ? nil : opts.note,
        url: opts.url.isEmpty ? nil : URL(string: opts.url)
    )
    let saved = try await store.add(item)
    try? ActivityLog.write(tool: "reminders", cmd: "add", desc: title, container: saved.list.title)
    return formatAddConfirmation(
        title: title, list: saved.list.title,
        details: AddConfirmationDetails(
            date: parsedDate, recurrence: recurrenceSpec,
            priority: opts.priority, hasNote: !opts.note.isEmpty, url: opts.url
        )
    )
}
