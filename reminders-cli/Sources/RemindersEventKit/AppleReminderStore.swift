// AppleReminderStore.swift
// EventKit implementation of ReminderStore.

import EventKit
import Foundation
import RemindersLib

enum AppleStoreError: LocalizedError {
    case noDefaultList
    case listNotFound(String)
    case reminderNotFound(String)

    var errorDescription: String? {
        switch self {
        case .noDefaultList:             return "No default reminders list found"
        case .listNotFound(let name):    return "List not found: \(name)"
        case .reminderNotFound(let id):  return "Reminder not found: \(id)"
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
        return await withCheckedContinuation { continuation in
            ek.fetchReminders(matching: predicate) {
                continuation.resume(returning: ($0 ?? []).map(ReminderItem.init))
            }
        }
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

// MARK: - EKReminder ↔ ReminderItem

extension ReminderItem {
    init(_ r: EKReminder) {
        self.init(
            identifier:            r.calendarItemIdentifier,
            title:                 r.title ?? "",
            list:                  ReminderList(ekCalendar: r.calendar),
            dueDateComponents:     r.dueDateComponents,
            recurrenceDescription: r.recurrenceRules?.first.map { describeEKRule($0) },
            priority:              r.priority,
            notes:                 r.notes,
            url:                   r.url,
            creationDate:          r.creationDate
        )
    }
}

extension ReminderList {
    init(ekCalendar cal: EKCalendar) {
        self.init(
            identifier:   cal.calendarIdentifier,
            title:        cal.title,
            color:        hexColor(from: cal.cgColor),
            source:       cal.source.title,
            isModifiable: cal.allowsContentModifications
        )
    }
}

// MARK: - Recurrence conversion

private func toEKRule(_ spec: RecurrenceSpec) -> EKRecurrenceRule {
    let ekFreqs: [RecurrenceFrequency: EKRecurrenceFrequency] =
        [.daily: .daily, .weekly: .weekly, .monthly: .monthly, .yearly: .yearly]
    if let ow = spec.ordinalWeekday {
        let dow = EKRecurrenceDayOfWeek(
            dayOfTheWeek: EKWeekday(rawValue: ow.weekday)!,
            weekNumber: ow.weekNumber)
        return monthlyEKRule(daysOfTheWeek: [dow])
    }
    if let day = spec.dayOfMonth {
        return monthlyEKRule(daysOfTheMonth: [NSNumber(value: day)])
    }
    return EKRecurrenceRule(recurrenceWith: ekFreqs[spec.frequency]!, interval: spec.interval, end: nil)
}

private func monthlyEKRule(
    daysOfTheWeek: [EKRecurrenceDayOfWeek]? = nil,
    daysOfTheMonth: [NSNumber]? = nil
) -> EKRecurrenceRule {
    EKRecurrenceRule(recurrenceWith: .monthly, interval: 1,
                     daysOfTheWeek: daysOfTheWeek, daysOfTheMonth: daysOfTheMonth,
                     monthsOfTheYear: nil, weeksOfTheYear: nil,
                     daysOfTheYear: nil, setPositions: nil, end: nil)
}

private func describeEKRule(_ rule: EKRecurrenceRule) -> String {
    describeRecurrenceRule(frequency: rule.frequency.rawValue, interval: rule.interval)
}

// MARK: - Field assignment

private func applyChanges(_ changes: ReminderChanges, to reminder: EKReminder) {
    if case .cleared = changes.due { reminder.dueDateComponents = nil }
    if case .set(let comps) = changes.due { reminder.dueDateComponents = comps }

    if case .cleared = changes.recurrence {
        reminder.recurrenceRules?.forEach { reminder.removeRecurrenceRule($0) }
    }
    if case .set(let spec) = changes.recurrence {
        reminder.recurrenceRules?.forEach { reminder.removeRecurrenceRule($0) }
        reminder.addRecurrenceRule(toEKRule(spec))
    }

    if case .set(let p) = changes.priority { reminder.priority = p }

    if case .cleared = changes.note { reminder.notes = nil }
    if case .set(let n) = changes.note { reminder.notes = n }

    if case .cleared = changes.url { reminder.url = nil }
    if case .set(let url) = changes.url { reminder.url = url }
}

// MARK: - CGColor to hex

private func hexColor(from cgColor: CGColor?) -> String? {
    guard let cg = cgColor, let components = cg.components, !components.isEmpty else { return nil }
    let r, g, b: Int
    switch cg.colorSpace?.model {
    case .rgb where components.count >= 3:
        r = Int(components[0] * 255); g = Int(components[1] * 255); b = Int(components[2] * 255)
    case .monochrome where components.count >= 1:
        let w = Int(components[0] * 255); r = w; g = w; b = w
    default: return nil
    }
    return String(format: "%02X%02X%02X", r, g, b)
}
