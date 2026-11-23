// RecapSelectionSpec.swift
//
// Tests for get-clear RecapSelection — which calendars a recap covers and which events are past.

import CalendarLib
import Foundation
@testable import GetClear
import Testing

private let work = CalendarItem(identifier: "work", title: "Work", kind: .calDAV)
private let home = CalendarItem(identifier: "home", title: "Home", kind: .local)
private let holidays = CalendarItem(identifier: "hol", title: "US Holidays", kind: .subscription)
private let birthdays = CalendarItem(identifier: "bday", title: "Birthdays", kind: .birthday)

private var utc: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC") ?? .current
    return cal
}

private let dayStart = Date(timeIntervalSince1970: 1_790_035_200) // a UTC midnight
private let range = dayStart ... dayStart.addingTimeInterval(86399)

private func event(start: TimeInterval, end: TimeInterval?, allDay: Bool = false) -> EventItem {
    EventItem(
        identifier: "e", title: "E", startDate: dayStart.addingTimeInterval(start),
        endDate: end.map { dayStart.addingTimeInterval($0) }, isAllDay: allDay, calendarTitle: "Work"
    )
}

@Suite("recapCalendarIDs")
struct RecapCalendarIDsTests {
    @Test("with no configured names, covers only the user's own calendars")
    func defaultScope() {
        #expect(recapCalendarIDs(names: nil, from: [work, holidays, home, birthdays]) == ["work", "home"])
    }

    @Test("with configured names, covers exactly the calendars with those titles")
    func namedScope() {
        #expect(recapCalendarIDs(names: ["US Holidays"], from: [work, holidays]) == ["hol"])
    }

    @Test("names that match no calendar fall back to all calendars")
    func noMatchFallsBack() {
        #expect(recapCalendarIDs(names: ["Gone"], from: [work, home]) == nil)
    }

    @Test("when the user has no calendars of their own, falls back to all calendars")
    func noUserCalendars() {
        #expect(recapCalendarIDs(names: nil, from: [holidays, birthdays]) == nil)
    }
}

@Suite("pastEvents")
struct PastEventsTests {
    @Test("a timed event that has ended is included")
    func endedIncluded() {
        let e = event(start: 3600, end: 7200)
        #expect(pastEvents([e], in: range, now: dayStart.addingTimeInterval(7200), calendar: utc) == [e])
    }

    @Test("a timed event still in progress is left out")
    func inProgressExcluded() {
        let e = event(start: 3600, end: 7200)
        #expect(pastEvents([e], in: range, now: dayStart.addingTimeInterval(5000), calendar: utc).isEmpty)
    }

    @Test("an all-day event on a day inside the range is included before the day ends")
    func allDayIncluded() {
        let e = event(start: 0, end: 86400, allDay: true)
        #expect(pastEvents([e], in: range, now: dayStart.addingTimeInterval(60), calendar: utc) == [e])
    }

    @Test("an all-day event that started the day before the range is left out")
    func allDayBeforeRangeExcluded() {
        let e = event(start: -86400, end: 0, allDay: true)
        #expect(pastEvents([e], in: range, now: dayStart.addingTimeInterval(86000), calendar: utc).isEmpty)
    }

    @Test("a timed event with no end time counts as ended once it has started")
    func noEndUsesStart() {
        let e = event(start: 3600, end: nil)
        #expect(pastEvents([e], in: range, now: dayStart.addingTimeInterval(3600), calendar: utc) == [e])
    }
}
