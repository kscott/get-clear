// ChangeApplier.swift
// Applies a ReminderChanges value to an EKReminder in place.
// Pure assignment — no business logic. List resolution and URL parsing happen upstream.

import Foundation
import EventKit
import RemindersLib

func applyChanges(_ changes: ReminderChanges, to reminder: EKReminder) {
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
