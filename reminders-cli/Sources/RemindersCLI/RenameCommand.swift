// RenameCommand.swift

import EventKit
import GetClearKit
import RemindersLib

func handleRename(args: [String], store: EKEventStore) async {
    guard args.count > 2 else { fail("provide existing title and new title") }
    let oldTitle = args[1]
    let newTitle = args[2]
    let list     = args.count > 3 ? args[3] : nil
    let reminder = await resolveReminder(title: oldTitle, list: list, cmd: "rename",
                                         calendars: store.calendars(for: .reminder), store: store)
    reminder.title = newTitle
    commitAndLog(
        { try store.save(reminder, commit: true) },
        cmd: "rename", desc: "\(oldTitle) → \(newTitle)", container: reminder.calendar.title,
        confirmation: "Renamed: \"\(oldTitle)\" → \"\(newTitle)\"",
        failMessage: "Could not rename")
}
