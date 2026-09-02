// EventDateTimeSpec.swift
//
// Tests for CalendarLib EventDateTime — date/time string parsing for calendar add.

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

private func hour(_ date: Date) -> Int {
    cal.component(.hour, from: date)
}

private func minute(_ date: Date) -> Int {
    cal.component(.minute, from: date)
}

private func day(_ date: Date) -> Int {
    cal.component(.day, from: date)
}

private func month(_ date: Date) -> Int {
    cal.component(.month, from: date)
}

private func year(_ date: Date) -> Int {
    cal.component(.year, from: date)
}

@Suite("parseEventDateTime")
struct EventDateTimeTests {
    // MARK: All-day events

    @Suite("all-day events")
    struct AllDayEvents {
        @Test("'today' produces an all-day event")
        func todayIsAllDay() {
            #expect(parseEventDateTime("today", relativeTo: now)?.isAllDay == true)
        }

        @Test("'today' start is midnight of the reference date")
        func todayStartIsMidnight() {
            let result = parseEventDateTime("today", relativeTo: now)
            #expect(result.map { hour($0.start) == 0 && minute($0.start) == 0 } == true)
        }

        @Test("'today' start is on January 15")
        func todayStartIsJan15() {
            #expect(parseEventDateTime("today", relativeTo: now).map { day($0.start) } == 15)
        }

        @Test("'today' end is 23:59:59 of the reference date")
        func todayEndIsEndOfDay() {
            let result = parseEventDateTime("today", relativeTo: now)
            #expect(result.flatMap(\.end).map {
                hour($0) == 23 && minute($0) == 59
            } == true)
        }

        @Test("'tomorrow' is all-day")
        func tomorrowIsAllDay() {
            #expect(parseEventDateTime("tomorrow", relativeTo: now)?.isAllDay == true)
        }

        @Test("'tomorrow' start is January 16")
        func tomorrowStartIsJan16() {
            #expect(parseEventDateTime("tomorrow", relativeTo: now).map { day($0.start) } == 16)
        }

        @Test("'friday' is all-day")
        func fridayIsAllDay() {
            #expect(parseEventDateTime("friday", relativeTo: now)?.isAllDay == true)
        }

        @Test("'friday' from Thursday resolves to January 16")
        func fridayResolvesToJan16() {
            #expect(parseEventDateTime("friday", relativeTo: now).map { day($0.start) } == 16)
        }

        @Test("'march 15' is all-day")
        func march15IsAllDay() {
            #expect(parseEventDateTime("march 15", relativeTo: now)?.isAllDay == true)
        }

        @Test("'march 15' start is in March")
        func march15StartInMarch() {
            #expect(parseEventDateTime("march 15", relativeTo: now).map { month($0.start) } == 3)
        }

        @Test("'march 15' start is on the 15th")
        func march15StartOn15th() {
            #expect(parseEventDateTime("march 15", relativeTo: now).map { day($0.start) } == 15)
        }

        @Test("'2026-04-01' is all-day")
        func isoIsAllDay() {
            #expect(parseEventDateTime("2026-04-01", relativeTo: now)?.isAllDay == true)
        }

        @Test("'2026-04-01' start is April 1 2026")
        func isoStartIsApr1() {
            let result = parseEventDateTime("2026-04-01", relativeTo: now)
            #expect(result.map { year($0.start) == 2026 && month($0.start) == 4 && day($0.start) == 1 } == true)
        }
    }

    // MARK: Timed events — explicit start and end

    @Suite("timed events with explicit start and end")
    struct TimedEventsExplicit {
        @Test("'today 2pm to 3pm' is not all-day")
        func notAllDay() {
            #expect(parseEventDateTime("today 2pm to 3pm", relativeTo: now)?.isAllDay == false)
        }

        @Test("'today 2pm to 3pm' starts at 14:00")
        func startsAt14() {
            #expect(parseEventDateTime("today 2pm to 3pm", relativeTo: now).map { hour($0.start) } == 14)
        }

        @Test("'today 2pm to 3pm' ends at 15:00")
        func endsAt15() {
            #expect(parseEventDateTime("today 2pm to 3pm", relativeTo: now).flatMap(\.end).map { hour($0) } == 15)
        }

        @Test("'today 2pm to 3pm' start is on January 15")
        func startOnJan15() {
            #expect(parseEventDateTime("today 2pm to 3pm", relativeTo: now).map { day($0.start) } == 15)
        }

        @Test("'tomorrow 9am to 11am' starts at 09:00")
        func tomorrowStartsAt9() {
            #expect(parseEventDateTime("tomorrow 9am to 11am", relativeTo: now).map { hour($0.start) } == 9)
        }

        @Test("'tomorrow 9am to 11am' ends at 11:00")
        func tomorrowEndsAt11() {
            #expect(parseEventDateTime("tomorrow 9am to 11am", relativeTo: now).flatMap(\.end).map { hour($0) } == 11)
        }

        @Test("'tomorrow 9am to 11am' start is on January 16")
        func tomorrowStartOnJan16() {
            #expect(parseEventDateTime("tomorrow 9am to 11am", relativeTo: now).map { day($0.start) } == 16)
        }

        @Test("'today 9:30am to 11am' start minute is 30")
        func startMinuteIs30() {
            #expect(parseEventDateTime("today 9:30am to 11am", relativeTo: now).map { minute($0.start) } == 30)
        }

        @Test("'today 9:30am to 11am' ends at 11:00")
        func nineThirtyEndsAt11() {
            #expect(parseEventDateTime("today 9:30am to 11am", relativeTo: now).flatMap(\.end).map { hour($0) } == 11)
        }

        @Test("'friday 2pm to 3pm' start is on January 16")
        func fridayStartOnJan16() {
            #expect(parseEventDateTime("friday 2pm to 3pm", relativeTo: now).map { day($0.start) } == 16)
        }
    }

    // MARK: Timed events — single time, 1-hour default duration

    @Suite("timed events with a single time — 1-hour default duration")
    struct TimedEventsSingleTime {
        @Test("'monday at 2pm' is not all-day")
        func notAllDay() {
            #expect(parseEventDateTime("monday at 2pm", relativeTo: now)?.isAllDay == false)
        }

        @Test("'monday at 2pm' starts at hour 14")
        func startsAt14() {
            #expect(parseEventDateTime("monday at 2pm", relativeTo: now).map { hour($0.start) } == 14)
        }

        @Test("'monday at 2pm' ends 1 hour after start")
        func endsOneHourAfterStart() {
            let result = parseEventDateTime("monday at 2pm", relativeTo: now)
            let startH = result.map { hour($0.start) }
            let endH = result.flatMap(\.end).map { hour($0) }
            #expect(endH == startH.map { $0 + 1 })
        }

        @Test("time with no date part defaults to the reference date")
        func noDatePartDefaultsToReference() {
            #expect(parseEventDateTime("2pm to 3pm", relativeTo: now).map { day($0.start) } == 15)
        }
    }

    // MARK: AM/PM edge cases

    @Suite("AM/PM edge cases")
    struct AMPMEdgeCases {
        @Test("'12pm' resolves to hour 12 (noon)")
        func twelvePMIsNoon() {
            #expect(parseEventDateTime("today 12pm to 1pm", relativeTo: now).map { hour($0.start) } == 12)
        }

        @Test("'12am' resolves to hour 0 (midnight)")
        func twelveAMIsMidnight() {
            #expect(parseEventDateTime("today 12am to 1am", relativeTo: now).map { hour($0.start) } == 0)
        }

        @Test("'2am' resolves to hour 2")
        func twoAMIsHour2() {
            #expect(parseEventDateTime("today 2am to 3am", relativeTo: now).map { hour($0.start) } == 2)
        }

        @Test("input is case-insensitive for AM/PM")
        func caseInsensitiveAMPM() {
            let lower = parseEventDateTime("today 2pm to 3pm", relativeTo: now).map { hour($0.start) }
            let upper = parseEventDateTime("today 2PM to 3PM", relativeTo: now).map { hour($0.start) }
            #expect(lower == upper)
        }
    }

    // MARK: Invalid input

    @Suite("invalid input")
    struct InvalidInput {
        @Test("returns nil for completely unrecognized input")
        func nilForUnrecognized() {
            #expect(parseEventDateTime("banana", relativeTo: now) == nil)
        }

        @Test("returns nil for empty string")
        func nilForEmpty() {
            #expect(parseEventDateTime("", relativeTo: now) == nil)
        }

        @Test("returns nil when the date part is unrecognizable")
        func nilForUnrecognizableDatePart() {
            #expect(parseEventDateTime("notadate 2pm to 3pm", relativeTo: now) == nil)
        }
    }
}
