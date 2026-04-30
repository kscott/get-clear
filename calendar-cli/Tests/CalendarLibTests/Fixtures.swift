// Fixtures.swift
// Shared test data for CalendarLibTests.

import CalendarLib
import Foundation

// MARK: - Shared calendar constants

let workCal = CalendarItem(identifier: "id-work", title: "Work", source: "iCloud")
let personalCal = CalendarItem(identifier: "id-personal", title: "Personal", source: "iCloud")

// MARK: - Event factory

func makeEvent(
    identifier: String = "evt-1",
    title: String = "Team Sync",
    startHour: Int = 10,
    endHour: Int = 11,
    dayOffset: Int = 0,
    isAllDay: Bool = false,
    calendarTitle: String = "Work",
    calendarIdentifier: String? = "id-work",
    calendarColor: String? = nil,
    location: String? = nil,
    notes: String? = nil,
    url: URL? = nil,
    attendees: [AttendeeItem] = []
) -> EventItem {
    let cal = Calendar.current
    var base = DateComponents()
    base.year = 2026
    base.month = 4
    base.day = 29 + dayOffset
    let day = cal.date(from: base)!

    let startDate: Date
    let endDate: Date?
    if isAllDay {
        startDate = cal.startOfDay(for: day)
        endDate = cal.date(byAdding: DateComponents(day: 1, second: -1), to: startDate)
    } else {
        var sc = base
        sc.hour = startHour
        sc.minute = 0
        var ec = base
        ec.hour = endHour
        ec.minute = 0
        startDate = cal.date(from: sc)!
        endDate = cal.date(from: ec)!
    }

    return EventItem(
        identifier: identifier,
        title: title,
        startDate: startDate,
        endDate: endDate,
        isAllDay: isAllDay,
        calendarTitle: calendarTitle,
        calendarIdentifier: calendarIdentifier,
        calendarColor: calendarColor,
        location: location,
        notes: notes,
        url: url,
        attendees: attendees
    )
}

func ambiguousEvents(title: String = "All Hands") -> [EventItem] {
    [makeEvent(identifier: "evt-a", title: title, dayOffset: 0),
     makeEvent(identifier: "evt-b", title: title, dayOffset: 7)]
}

// MARK: - SpyCalendarStore

final class SpyCalendarStore: CalendarStore {
    var calendars: [CalendarItem] = [workCal, personalCal]
    var events: [EventItem] = []

    var addedItems: [EventItem] = []
    var removedIds: [String] = []

    func fetchCalendars() async throws -> [CalendarItem] {
        calendars
    }

    func fetchEvents(in range: DateInterval, calendarIdentifiers: [String]?) async throws -> [EventItem] {
        events
    }

    func add(_ item: EventItem) async throws -> EventItem {
        addedItems.append(item)
        return item
    }

    func remove(identifier: String) async throws {
        removedIds.append(identifier)
    }
}
