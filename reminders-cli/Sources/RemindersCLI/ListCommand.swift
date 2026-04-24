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
    let items     = reminders.map(ReminderItem.init)
    let calByTitle = Dictionary(listCalendars.map { ($0.title, $0) }, uniquingKeysWith: { first, _ in first })

    if filterList != nil {
        for item in sorted(items, by: order) {
            let dot = calByTitle[item.calendarTitle].map { calendarDot($0) } ?? "  "
            print("\(dot)\(formatListRow(item))")
        }
    } else {
        for (header, groupItems) in groupedByList(items, sortedBy: order) {
            let dot = calByTitle[header].map { calendarDot($0) } ?? "  "
            print("\(dot)\(ANSI.bold(header))")
            for item in groupItems {
                print("\(dot)\(formatListRow(item))")
            }
        }
    }
}
