// RemoveCommand.swift

import EventKit
import GetClearKit
import RemindersLib

func handleRemove(args: [String], store: EKEventStore) async {
    guard args.count > 1 else { fail("provide a reminder title") }
    let title     = args[1]
    let list      = args.count > 2 ? args[2] : nil
    let reminder  = await resolveReminder(title: title, list: list, cmd: "remove",
                                          calendars: store.calendars(for: .reminder), store: store)
    let container = reminder.calendar.title
    commitAndLog(
        { try store.remove(reminder, commit: true) },
        cmd: "remove", desc: title, container: container,
        confirmation: "Removed: \(title)",
        failMessage: "Could not remove")
}
