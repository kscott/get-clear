// ReminderConversion.swift
// Converts EKReminder ↔ ReminderItem at the EventKit boundary.

import EventKit
import RemindersLib

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

func hexColor(from cgColor: CGColor?) -> String? {
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
