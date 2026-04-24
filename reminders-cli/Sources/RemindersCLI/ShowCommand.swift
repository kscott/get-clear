// ShowCommand.swift

import EventKit
import GetClearKit
import RemindersLib

func handleShow(args: [String], store: EKEventStore) async {
    guard args.count > 1 else { fail("provide a reminder title") }
    let list     = args.count > 2 ? args[2] : nil
    let reminder = await resolveReminder(title: args[1], list: list, cmd: "show",
                                         calendars: store.calendars(for: .reminder), store: store)
    print(formatShow(item: ReminderItem(reminder)))
}
