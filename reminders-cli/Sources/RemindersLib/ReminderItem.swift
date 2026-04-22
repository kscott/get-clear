// ReminderItem.swift
// A pure value type capturing the data fields of a reminder, independent of EventKit.

import Foundation

public struct ReminderItem: Equatable {
    public let title: String
    public let calendarTitle: String
    public let dueDateComponents: DateComponents?
    public let hasRecurrenceRules: Bool
    public let priority: Int
    public let notes: String?
    public let url: URL?
    public let creationDate: Date?

    public init(
        title: String,
        calendarTitle: String,
        dueDateComponents: DateComponents? = nil,
        hasRecurrenceRules: Bool = false,
        priority: Int = 0,
        notes: String? = nil,
        url: URL? = nil,
        creationDate: Date? = nil
    ) {
        self.title              = title
        self.calendarTitle      = calendarTitle
        self.dueDateComponents  = dueDateComponents
        self.hasRecurrenceRules = hasRecurrenceRules
        self.priority           = priority
        self.notes              = notes
        self.url                = url
        self.creationDate       = creationDate
    }
}
