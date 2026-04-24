// ReminderResolver.swift
// Fetches reminders from the EventKit store and resolves a single match using ReminderLookup.

import EventKit
import GetClearKit
import RemindersLib

func resolveReminder(
    title: String,
    list: String?,
    cmd: String,
    calendars: [EKCalendar],
    store: EKEventStore
) async -> EKReminder {
    let scope: [EKCalendar]
    if let list {
        guard let cal = calendars.first(where: { $0.title == list }) else {
            fail("List not found: \(list)")
        }
        scope = [cal]
    } else {
        scope = calendars
    }
    // Intentionally incomplete-only: once a reminder is marked done it disappears from
    // this tool's perspective. remove, change, rename, and done all operate in the same
    // space — completed reminders are out of scope for every mutating command.
    let predicate = store.predicateForIncompleteReminders(
        withDueDateStarting: nil, ending: nil, calendars: scope)
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
