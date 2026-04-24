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
    let filterName = listArgs.first

    let listCalendars: [EKCalendar]
    if let filterName {
        guard let cal = store.calendars(for: .reminder).first(where: { $0.title == filterName }) else {
            fail("List not found: \(filterName)")
        }
        listCalendars = [cal]
    } else {
        listCalendars = store.calendars(for: .reminder)
    }

    let predicate = store.predicateForIncompleteReminders(
        withDueDateStarting: nil, ending: nil, calendars: listCalendars)
    let reminders = await fetchReminders(matching: predicate, from: store)
    let items     = reminders.map(ReminderItem.init)

    if filterName != nil {
        for item in sorted(items, by: order) {
            print("\(calendarDot(hex: item.list.color))\(formatListRow(item))")
        }
    } else {
        for (list, groupItems) in groupedByList(items, sortedBy: order) {
            let dot = calendarDot(hex: list.color)
            print("\(dot)\(ANSI.bold(list.title))")
            for item in groupItems {
                print("\(dot)\(formatListRow(item))")
            }
        }
    }
}
