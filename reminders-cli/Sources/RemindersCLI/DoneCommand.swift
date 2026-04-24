// DoneCommand.swift

import EventKit
import GetClearKit
import RemindersLib

func handleDone(args: [String], store: EKEventStore) async {
    guard args.count > 1 else { fail("provide a reminder title") }
    let title    = args[1]
    let list     = args.count > 2 ? args[2] : nil
    let reminder = await resolveReminder(title: title, list: list, cmd: "done",
                                         calendars: store.calendars(for: .reminder), store: store)
    reminder.isCompleted = true
    commitAndLog(
        { try store.save(reminder, commit: true) },
        cmd: "done", desc: title, container: reminder.calendar.title,
        confirmation: "Done: \(title)")
}
