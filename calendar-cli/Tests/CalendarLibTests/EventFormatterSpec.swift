// EventFormatterSpec.swift
// Tests for CalendarLib EventFormatter — event line and relative label formatting.

import CalendarLib
import Foundation
import Testing

private let cal = Calendar.current

/// Fixed reference: Thursday January 15, 2026 at noon
private let now: Date = {
    var c = DateComponents()
    c.year = 2026
    c.month = 1
    c.day = 15
    c.hour = 12
    c.minute = 0
    c.second = 0
    return cal.date(from: c)!
}()

private func makeDate(hour: Int, minute: Int = 0, dayOffset: Int = 0) -> Date {
    var c = DateComponents()
    c.year = 2026
    c.month = 1
    c.day = 15 + dayOffset
    c.hour = hour
    c.minute = minute
    c.second = 0
    return cal.date(from: c)!
}

private func timedEvent(
    title: String = "Test Event",
    startHour: Int = 14, endHour: Int = 15,
    dayOffset: Int = 0,
    location: String? = nil,
    calendarTitle: String = "Work",
    calendarColor: String? = nil
) -> EventItem {
    EventItem(
        identifier: "test-id",
        title: title,
        startDate: makeDate(hour: startHour, dayOffset: dayOffset),
        endDate: makeDate(hour: endHour, dayOffset: dayOffset),
        isAllDay: false,
        calendarTitle: calendarTitle,
        calendarColor: calendarColor,
        location: location
    )
}

private func allDayEvent(
    title: String = "Holiday",
    dayOffset: Int = 0,
    location: String? = nil,
    calendarTitle: String = "Home"
) -> EventItem {
    let start = cal.startOfDay(for: makeDate(hour: 0, dayOffset: dayOffset))
    let end = cal.date(byAdding: DateComponents(day: 1, second: -1), to: start)
    return EventItem(
        identifier: "all-day-id",
        title: title,
        startDate: start,
        endDate: end,
        isAllDay: true,
        calendarTitle: calendarTitle,
        location: location
    )
}

// MARK: - eventLine

@Suite("eventLine")
struct EventLineTests {
    @Suite("timed events")
    struct TimedEvents {
        @Test("contains the event title")
        func containsTitle() {
            let line = eventLine(for: timedEvent(title: "Team Sync"))
            #expect(line.contains("Team Sync"))
        }

        @Test("does not contain 'All day'")
        func noAllDay() {
            let line = eventLine(for: timedEvent())
            #expect(!line.contains("All day"))
        }

        @Test("contains the start time")
        func containsStartTime() {
            let event = timedEvent(startHour: 14, endHour: 15)
            let line = eventLine(for: event)
            #expect(line.contains(formatEventTime(event.startDate)))
        }

        @Test("contains the end time")
        func containsEndTime() throws {
            let event = timedEvent(startHour: 14, endHour: 15)
            let line = eventLine(for: event)
            #expect(try line.contains(formatEventTime(#require(event.endDate))))
        }
    }

    @Suite("all-day events")
    struct AllDayEvents {
        @Test("contains 'All day'")
        func containsAllDay() {
            let line = eventLine(for: allDayEvent())
            #expect(line.contains("All day"))
        }

        @Test("contains the event title")
        func containsTitle() {
            let line = eventLine(for: allDayEvent(title: "New Year"))
            #expect(line.contains("New Year"))
        }

        @Test("does not contain a time")
        func noTime() {
            let event = allDayEvent()
            let line = eventLine(for: event)
            #expect(!line.contains(formatEventTime(event.startDate)))
        }
    }

    @Suite("location")
    struct Location {
        @Test("appends location after ' · ' separator")
        func appendsAfterSeparator() {
            let line = eventLine(for: timedEvent(location: "Zoom"))
            #expect(line.contains(" · Zoom"))
        }

        @Test("uses only the first line of a multi-line location")
        func usesFirstLineOnly() {
            let line = eventLine(for: timedEvent(location: "123 Main St\nFloor 2"))
            #expect(line.contains("123 Main St"))
        }

        @Test("omits subsequent lines of a multi-line location")
        func omitsSubsequentLines() {
            let line = eventLine(for: timedEvent(location: "123 Main St\nFloor 2"))
            #expect(!line.contains("Floor 2"))
        }

        @Test("truncates location longer than 50 characters")
        func truncatesLongLocation() {
            let long = String(repeating: "A", count: 60)
            let line = eventLine(for: timedEvent(location: long))
            #expect(line.contains("…"))
            #expect(!line.contains(long))
        }

        @Test("does not truncate a location of exactly 50 characters")
        func noTruncateExactly50() {
            let exact = String(repeating: "B", count: 50)
            let line = eventLine(for: timedEvent(location: exact))
            #expect(!line.contains("…"))
        }

        @Test("omits ' · ' when location is nil")
        func omitsSeparatorWhenNil() {
            let line = eventLine(for: timedEvent(location: nil))
            #expect(!line.contains(" · "))
        }

        @Test("omits ' · ' when location is empty")
        func omitsSeparatorWhenEmpty() {
            let line = eventLine(for: timedEvent(location: ""))
            #expect(!line.contains(" · "))
        }
    }
}

// MARK: - nextRelativeLabel

@Suite("nextRelativeLabel")
struct NextRelativeLabelTests {
    @Suite("today")
    struct Today {
        @Test("returns a label starting with 'Today' for the reference date")
        func startsWithToday() {
            let label = nextRelativeLabel(for: now, relativeTo: now)
            #expect(label.hasPrefix("Today"))
        }
    }

    @Suite("tomorrow")
    struct Tomorrow {
        @Test("returns a label starting with 'Tomorrow' for one day ahead")
        func startsWithTomorrow() throws {
            let tomorrow = try #require(cal.date(byAdding: .day, value: 1, to: now))
            let label = nextRelativeLabel(for: tomorrow, relativeTo: now)
            #expect(label.hasPrefix("Tomorrow"))
        }
    }

    @Suite("within 7 days")
    struct WithinSevenDays {
        @Test("returns an abbreviated day name for a date 5 days out")
        func abbreviatedDayName() throws {
            // Jan 20 2026 is a Tuesday — 5 days after Jan 15
            let tuesday = try #require(cal.date(byAdding: .day, value: 5, to: now))
            let label = nextRelativeLabel(for: tuesday, relativeTo: now)
            #expect(label.hasPrefix("Tue"))
        }

        @Test("does not return 'Today' or 'Tomorrow' for a date within 7 days")
        func notTodayOrTomorrow() throws {
            let threeDays = try #require(cal.date(byAdding: .day, value: 3, to: now))
            let label = nextRelativeLabel(for: threeDays, relativeTo: now)
            #expect(!label.hasPrefix("Today"))
            #expect(!label.hasPrefix("Tomorrow"))
        }
    }

    @Suite("7 or more days away")
    struct SevenOrMoreDaysAway {
        @Test("returns a month+day label for a date 10 days out")
        func monthDayLabel() throws {
            // Jan 25 2026 — 10 days after Jan 15
            let tenDays = try #require(cal.date(byAdding: .day, value: 10, to: now))
            let label = nextRelativeLabel(for: tenDays, relativeTo: now)
            #expect(label.hasPrefix("Jan 25"))
        }

        @Test("does not use an abbreviated day name for a date 10 days out")
        func noAbbreviatedDayName() throws {
            let tenDays = try #require(cal.date(byAdding: .day, value: 10, to: now))
            let label = nextRelativeLabel(for: tenDays, relativeTo: now)
            #expect(!label.hasPrefix("Sun"))
        }
    }
}
