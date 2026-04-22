// RenameCommand.swift

import EventKit
import GetClearKit
import RemindersLib

func handleRename(args: [String], store: EKEventStore) async {
    guard args.count > 2 else { fail("provide existing title and new title") }
    let oldTitle = args[1]
    let newTitle = args[2]
    let list     = args.count > 3 ? args[3] : nil
    let reminder = await resolveReminder(title: oldTitle, list: list, cmd: "rename", store: store)
    reminder.title = newTitle
    do {
        try store.save(reminder, commit: true)
        try? ActivityLog.write(tool: "reminders", cmd: "rename",
                               desc: "\(oldTitle) → \(newTitle)", container: reminder.calendar.title)
        print("Renamed: \"\(oldTitle)\" → \"\(newTitle)\"")
    } catch {
        fail("Could not rename: \(error.localizedDescription)")
    }
}
