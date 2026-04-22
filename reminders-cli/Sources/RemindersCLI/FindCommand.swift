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
    let items = reminders.map(ReminderItem.init)
    let cmp   = comparator(for: .due)
    let pairs = Array(zip(reminders, items))
        .filter { matchesQuery($0.1, query: query) }
        .sorted { cmp($0.1, $1.1) }
    if pairs.isEmpty {
        print("No reminders matching '\(query)'")
    } else {
        for (reminder, item) in pairs {
            print("\(calendarDot(reminder.calendar))\(formatFindRow(item))")
        }
    }
}
