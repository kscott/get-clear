// ReminderItem.swift
// A pure value type capturing the data fields of a reminder, independent of EventKit.

import Foundation

public struct ReminderItem: Equatable {
    public let identifier: String
    public let title: String
    public let list: ReminderList
    public let dueDateComponents: DateComponents?
    /// Human-readable recurrence string (e.g. "weekly") — populated by the store when fetching.
    public let recurrenceDescription: String?
    /// Recurrence spec for creation — set by handlers, consumed by the store's add() method.
    public let recurrenceSpec: RecurrenceSpec?
    public let priority: Int
    public let notes: String?
    public let url: URL?
    public let creationDate: Date?

    public var hasRecurrenceRules: Bool {
        recurrenceDescription != nil
    }

    public init(
        identifier: String = "",
        title: String,
        list: ReminderList,
        dueDateComponents: DateComponents? = nil,
        recurrenceDescription: String? = nil,
        recurrenceSpec: RecurrenceSpec? = nil,
        priority: Int = 0,
        notes: String? = nil,
        url: URL? = nil,
        creationDate: Date? = nil
    ) {
        self.identifier = identifier
        self.title = title
        self.list = list
        self.dueDateComponents = dueDateComponents
        self.recurrenceDescription = recurrenceDescription
        self.recurrenceSpec = recurrenceSpec
        self.priority = priority
        self.notes = notes
        self.url = url
        self.creationDate = creationDate
    }
}
