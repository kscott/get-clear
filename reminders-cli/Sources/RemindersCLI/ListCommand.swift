// ListCommand.swift

import EventKit
import GetClearKit
import RemindersLib

func handleList(args: [String], store: EKEventStore) async {
    var listArgs = Array(args.dropFirst())
    var order: ReminderSortOrder = .due
    if let byIdx = listArgs.firstIndex(of: "by"), byIdx + 1 < listArgs.count {
        order = ReminderSortOrder(rawValue: listArgs[byIdx + 1].lowercased()) ?? .due
        listArgs.removeSubrange(byIdx...(byIdx + 1))
    }
    let filterList = listArgs.first

    let listCalendars: [EKCalendar]
    if let filterList {
        guard let cal = store.calendars(for: .reminder).first(where: { $0.title == filterList }) else {
            fail("List not found: \(filterList)")
        }
        listCalendars = [cal]
    } else {
        listCalendars = store.calendars(for: .reminder)
    }

    let predicate = store.predicateForIncompleteReminders(
        withDueDateStarting: nil, ending: nil, calendars: listCalendars)
    let reminders = await fetchReminders(matching: predicate, from: store)
    let items = reminders.map(ReminderItem.init)
    let cmp   = comparator(for: order)
    let pairs = Array(zip(reminders, items))

    if filterList != nil {
        for (reminder, item) in pairs.sorted(by: { cmp($0.1, $1.1) }) {
            print("\(calendarDot(reminder.calendar))\(formatListRow(item))")
        }
    } else {
        let grouped = Dictionary(grouping: pairs, by: { $1.calendarTitle })
        for listName in grouped.keys.sorted() {
            let grpPairs = (grouped[listName] ?? []).sorted(by: { cmp($0.1, $1.1) })
            let dot = grpPairs.first.map { calendarDot($0.0.calendar) } ?? "  "
            print("\(dot)\(ANSI.bold(listName))")
            for (reminder, item) in grpPairs {
                print("\(calendarDot(reminder.calendar))\(formatListRow(item))")
            }
        }
    }
}
