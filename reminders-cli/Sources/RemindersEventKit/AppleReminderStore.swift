// AppleReminderStore.swift
// EventKit implementation of ReminderStore.

import EventKit
import RemindersLib

enum AppleStoreError: LocalizedError {
    case noDefaultList
    case listNotFound(String)
    case reminderNotFound(String)

    var errorDescription: String? {
        switch self {
        case .noDefaultList:           return "No default reminders list found"
        case .listNotFound(let name):  return "List not found: \(name)"
        case .reminderNotFound(let id): return "Reminder not found: \(id)"
        }
    }
}

public final class AppleReminderStore: ReminderStore {

    private let ek: EKEventStore

    public init(_ store: EKEventStore) { self.ek = store }

    public func fetchLists() async throws -> [ReminderList] {
        ek.calendars(for: .reminder).map(ReminderList.init(ekCalendar:))
    }

    public func defaultList() async throws -> ReminderList {
        guard let cal = ek.defaultCalendarForNewReminders() else {
            throw AppleStoreError.noDefaultList
        }
        return ReminderList(ekCalendar: cal)
    }

    public func fetchIncomplete(in list: ReminderList?) async throws -> [ReminderItem] {
        let scope: [EKCalendar]
        if let list {
            scope = ek.calendars(for: .reminder).filter {
                list.matches(identifier: $0.calendarIdentifier, title: $0.title)
            }
        } else {
            scope = ek.calendars(for: .reminder)
        }
        let predicate = ek.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: scope)
        return await fetchReminders(matching: predicate, from: ek).map(ReminderItem.init)
    }

    public func add(_ item: ReminderItem) async throws -> ReminderItem {
        guard let cal = calendar(for: item.list) else {
            throw AppleStoreError.listNotFound(item.list.title)
        }
        let reminder       = EKReminder(eventStore: ek)
        reminder.title     = item.title
        reminder.calendar  = cal
        reminder.dueDateComponents = item.dueDateComponents
        if let spec = item.recurrenceSpec { reminder.addRecurrenceRule(toEKRule(spec)) }
        reminder.priority = item.priority
        reminder.notes    = item.notes
        reminder.url      = item.url
        try ek.save(reminder, commit: true)
        return ReminderItem(reminder)
    }

    public func update(identifier: String, changes: ReminderChanges) async throws {
        let reminder = try ekReminder(identifier: identifier)
        if case .set(let targetName) = changes.list {
            guard let cal = calendar(for: ReminderList(title: targetName)) else {
                throw AppleStoreError.listNotFound(targetName)
            }
            reminder.calendar = cal
        }
        applyChanges(changes, to: reminder)
        try ek.save(reminder, commit: true)
    }

    public func complete(identifier: String) async throws {
        let reminder = try ekReminder(identifier: identifier)
        reminder.isCompleted = true
        try ek.save(reminder, commit: true)
    }

    public func rename(identifier: String, to title: String) async throws {
        let reminder = try ekReminder(identifier: identifier)
        reminder.title = title
        try ek.save(reminder, commit: true)
    }

    public func delete(identifier: String) async throws {
        let reminder = try ekReminder(identifier: identifier)
        try ek.remove(reminder, commit: true)
    }

    // MARK: - Private helpers

    private func ekReminder(identifier: String) throws -> EKReminder {
        guard let reminder = ek.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw AppleStoreError.reminderNotFound(identifier)
        }
        return reminder
    }

    private func calendar(for list: ReminderList) -> EKCalendar? {
        ek.calendars(for: .reminder).first {
            list.matches(identifier: $0.calendarIdentifier, title: $0.title)
        }
    }
}
