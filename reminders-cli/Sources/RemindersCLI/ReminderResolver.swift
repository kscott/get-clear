// ReminderResolver.swift
// Fetches reminders from the EventKit store and resolves a single match using ReminderLookup.

import EventKit
import GetClearKit
import RemindersLib

func resolveReminder(
    title: String,
    list: String?,
    cmd: String,
    store: EKEventStore
) async -> EKReminder {
    let calendars: [EKCalendar]
    if let list {
        guard let cal = store.calendars(for: .reminder).first(where: { $0.title == list }) else {
            fail("List not found: \(list)")
        }
        calendars = [cal]
    } else {
        calendars = store.calendars(for: .reminder)
    }
    let predicate = store.predicateForIncompleteReminders(
        withDueDateStarting: nil, ending: nil, calendars: calendars)
    let reminders = await fetchReminders(matching: predicate, from: store)
    let items     = reminders.map(ReminderItem.init)
    switch lookup(title: title, in: items) {
    case .found(let i):
        return reminders[i]
    case .notFound:
        fail(notFoundMessage(title: title, list: list))
    case .ambiguous(let indices):
        print(disambiguationMessage(title: title, matches: indices.map { items[$0] }, cmd: cmd))
        exit(1)
    }
}
