// FindCommand.swift

import EventKit
import GetClearKit
import RemindersLib

func handleFind(args: [String], store: EKEventStore) async {
    guard args.count > 1 else { fail("provide a search query") }
    let query = args.dropFirst().joined(separator: " ")
    let predicate = store.predicateForIncompleteReminders(
        withDueDateStarting: nil, ending: nil, calendars: store.calendars(for: .reminder))
    let reminders = await fetchReminders(matching: predicate, from: store)
    let items     = reminders.map(ReminderItem.init)
    let matched   = filtered(items, matching: query).sorted(by: comparator(for: .due))
    if matched.isEmpty {
        print("No reminders matching '\(query)'")
    } else {
        for item in matched {
            print("\(calendarDot(hex: item.list.color))\(formatFindRow(item))")
        }
    }
}
