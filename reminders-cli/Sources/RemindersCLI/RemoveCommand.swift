// RemoveCommand.swift

import EventKit
import GetClearKit
import RemindersLib

func handleRemove(args: [String], store: EKEventStore) async {
    guard args.count > 1 else { fail("provide a reminder title") }
    let title     = args[1]
    let list      = args.count > 2 ? args[2] : nil
    let reminder  = await resolveReminder(title: title, list: list, cmd: "remove", store: store)
    let container = reminder.calendar.title
    do {
        try store.remove(reminder, commit: true)
        try? ActivityLog.write(tool: "reminders", cmd: "remove", desc: title, container: container)
        print("Removed: \(title)")
    } catch {
        fail("Could not remove: \(error.localizedDescription)")
    }
}
