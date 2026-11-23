// EventItemSpec.swift
//
// Tests for CalendarLib EventItem — the event, attendee, and calendar value types.

import CalendarLib
import Foundation
import Testing

private func roundTrip<T: Codable>(_ value: T) throws -> T {
    try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
}

@Suite("EventItem coding")
struct EventItemCodingTests {
    @Test("an event with every field set survives a JSON round trip")
    func everyField() throws {
        let event = EventItem(
            identifier: "e-1",
            title: "All Hands",
            startDate: Date(timeIntervalSince1970: 1_790_000_000),
            endDate: Date(timeIntervalSince1970: 1_790_003_600),
            isAllDay: false,
            calendarTitle: "Work",
            calendarIdentifier: "id-work",
            calendarColor: "FF5733",
            location: "Room 4",
            notes: "bring numbers",
            url: URL(string: "https://example.com/meet"),
            attendees: [AttendeeItem(name: "Alice", status: "accepted")]
        )
        #expect(try roundTrip(event) == event)
    }

    @Test("an all-day event with no end date survives a JSON round trip")
    func allDayNoEnd() throws {
        let event = EventItem(
            identifier: "e-2", title: "Holiday", startDate: Date(timeIntervalSince1970: 1_790_000_000),
            endDate: nil, isAllDay: true, calendarTitle: "Personal"
        )
        #expect(try roundTrip(event) == event)
    }
}

@Suite("CalendarItem coding")
struct CalendarItemCodingTests {
    @Test("a calendar with every field set survives a JSON round trip")
    func everyField() throws {
        let calendar = CalendarItem(
            identifier: "id-work", title: "Work", color: "00FF00", source: "iCloud", isModifiable: false, kind: .exchange
        )
        #expect(try roundTrip(calendar) == calendar)
    }
}

@Suite("CalendarKind.isUserOwned")
struct CalendarKindTests {
    @Test("local, CalDAV, and Exchange calendars are the user's own", arguments: [CalendarKind.local, .calDAV, .exchange])
    func userOwned(kind: CalendarKind) {
        #expect(kind.isUserOwned)
    }

    @Test("subscribed, birthday, and unknown calendars are not", arguments: [CalendarKind.subscription, .birthday, .other])
    func notUserOwned(kind: CalendarKind) {
        #expect(!kind.isUserOwned)
    }

    @Test("a calendar is local unless the store says otherwise")
    func defaultsToLocal() {
        #expect(CalendarItem(identifier: "c", title: "Home").kind == .local)
    }
}
