// ReminderConversion.swift
// Converts EKReminder to ReminderItem — the thin boundary between EventKit and pure logic.

import EventKit
import RemindersLib

extension ReminderItem {
    init(_ r: EKReminder) {
        self.init(
            title:              r.title ?? "",
            calendarTitle:      r.calendar.title,
            dueDateComponents:  r.dueDateComponents,
            hasRecurrenceRules: r.hasRecurrenceRules,
            priority:           r.priority,
            notes:              r.notes,
            url:                r.url,
            creationDate:       r.creationDate
        )
    }
}
