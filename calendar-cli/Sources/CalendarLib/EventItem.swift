// EventItem.swift
// Pure value types for calendar data — no EventKit dependency.

import Foundation

public struct EventItem: Equatable, Codable, Sendable {
    public let identifier: String
    public let title: String
    public let startDate: Date
    public let endDate: Date?
    public let isAllDay: Bool
    public let calendarTitle: String
    public let calendarIdentifier: String?
    public let calendarColor: String? // 6-char uppercase hex, e.g. "FF5733"
    public let location: String?
    public let notes: String?
    public let url: URL?
    public let attendees: [AttendeeItem]

    public init(
        identifier: String,
        title: String,
        startDate: Date,
        endDate: Date?,
        isAllDay: Bool,
        calendarTitle: String,
        calendarIdentifier: String? = nil,
        calendarColor: String? = nil,
        location: String? = nil,
        notes: String? = nil,
        url: URL? = nil,
        attendees: [AttendeeItem] = []
    ) {
        self.identifier = identifier
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarTitle = calendarTitle
        self.calendarIdentifier = calendarIdentifier
        self.calendarColor = calendarColor
        self.location = location
        self.notes = notes
        self.url = url
        self.attendees = attendees
    }
}

public struct AttendeeItem: Equatable, Codable, Sendable {
    public let name: String
    public let status: String // "accepted", "declined", "tentative", "invited"

    public init(name: String, status: String) {
        self.name = name
        self.status = status
    }
}

/// Where a calendar's events come from.
public enum CalendarKind: String, Equatable, Codable, Sendable {
    case local
    case calDAV
    case exchange
    case subscription
    case birthday
    case other

    /// Calendars the user keeps themselves, as opposed to subscribed feeds and the
    /// generated Birthdays calendar. Recap's default scope.
    public var isUserOwned: Bool {
        switch self {
        case .local, .calDAV, .exchange: true
        case .subscription, .birthday, .other: false
        }
    }
}

public struct CalendarItem: Equatable, Codable, Sendable {
    public let identifier: String
    public let title: String
    public let color: String? // 6-char uppercase hex, nil for backends without color
    public let source: String? // account name
    public let isModifiable: Bool
    public let kind: CalendarKind

    public init(identifier: String, title: String, color: String? = nil,
                source: String? = nil, isModifiable: Bool = true, kind: CalendarKind = .local)
    {
        self.identifier = identifier
        self.title = title
        self.color = color
        self.source = source
        self.isModifiable = isModifiable
        self.kind = kind
    }
}
