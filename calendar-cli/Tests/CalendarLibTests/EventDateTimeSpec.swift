// EventDateTimeSpec.swift
//
// Tests for CalendarLib EventDateTime — date/time string parsing for calendar add.

import Quick
import Nimble
import Foundation
import CalendarLib

final class EventDateTimeSpec: QuickSpec {
    override class func spec() {
        // Fixed reference: Thursday January 15, 2026 at noon
        let cal = Calendar.current
        let now: Date = {
            var c = DateComponents()
            c.year = 2026; c.month = 1; c.day = 15
            c.hour = 12; c.minute = 0; c.second = 0
            return cal.date(from: c)!
        }()

        func hour(_ date: Date) -> Int   { cal.component(.hour,   from: date) }
        func minute(_ date: Date) -> Int { cal.component(.minute, from: date) }
        func day(_ date: Date) -> Int    { cal.component(.day,    from: date) }
        func month(_ date: Date) -> Int  { cal.component(.month,  from: date) }
        func year(_ date: Date) -> Int   { cal.component(.year,   from: date) }

        describe("parseEventDateTime") {

            // MARK: All-day events

            context("all-day events") {
                it("'today' produces an all-day event") {
                    expect(parseEventDateTime("today", relativeTo: now)?.isAllDay) == true
                }
                it("'today' start is midnight of the reference date") {
                    let result = parseEventDateTime("today", relativeTo: now)
                    expect(result.map { hour($0.start) == 0 && minute($0.start) == 0 }) == true
                }
                it("'today' start is on January 15") {
                    expect(parseEventDateTime("today", relativeTo: now).map { day($0.start) }) == 15
                }
                it("'today' end is 23:59:59 of the reference date") {
                    let result = parseEventDateTime("today", relativeTo: now)
                    expect(result.flatMap { $0.end }.map {
                        hour($0) == 23 && minute($0) == 59
                    }) == true
                }
                it("'tomorrow' is all-day") {
                    expect(parseEventDateTime("tomorrow", relativeTo: now)?.isAllDay) == true
                }
                it("'tomorrow' start is January 16") {
                    expect(parseEventDateTime("tomorrow", relativeTo: now).map { day($0.start) }) == 16
                }
                it("'friday' is all-day") {
                    expect(parseEventDateTime("friday", relativeTo: now)?.isAllDay) == true
                }
                it("'friday' from Thursday resolves to January 16") {
                    expect(parseEventDateTime("friday", relativeTo: now).map { day($0.start) }) == 16
                }
                it("'march 15' is all-day") {
                    expect(parseEventDateTime("march 15", relativeTo: now)?.isAllDay) == true
                }
                it("'march 15' start is in March") {
                    expect(parseEventDateTime("march 15", relativeTo: now).map { month($0.start) }) == 3
                }
                it("'march 15' start is on the 15th") {
                    expect(parseEventDateTime("march 15", relativeTo: now).map { day($0.start) }) == 15
                }
                it("'2026-04-01' is all-day") {
                    expect(parseEventDateTime("2026-04-01", relativeTo: now)?.isAllDay) == true
                }
                it("'2026-04-01' start is April 1 2026") {
                    let result = parseEventDateTime("2026-04-01", relativeTo: now)
                    expect(result.map { year($0.start) == 2026 && month($0.start) == 4 && day($0.start) == 1 }) == true
                }
            }

            // MARK: Timed events — explicit start and end

            context("timed events with explicit start and end") {
                it("'today 2pm to 3pm' is not all-day") {
                    expect(parseEventDateTime("today 2pm to 3pm", relativeTo: now)?.isAllDay) == false
                }
                it("'today 2pm to 3pm' starts at 14:00") {
                    expect(parseEventDateTime("today 2pm to 3pm", relativeTo: now).map { hour($0.start) }) == 14
                }
                it("'today 2pm to 3pm' ends at 15:00") {
                    expect(parseEventDateTime("today 2pm to 3pm", relativeTo: now).flatMap { $0.end }.map { hour($0) }) == 15
                }
                it("'today 2pm to 3pm' start is on January 15") {
                    expect(parseEventDateTime("today 2pm to 3pm", relativeTo: now).map { day($0.start) }) == 15
                }
                it("'tomorrow 9am to 11am' starts at 09:00") {
                    expect(parseEventDateTime("tomorrow 9am to 11am", relativeTo: now).map { hour($0.start) }) == 9
                }
                it("'tomorrow 9am to 11am' ends at 11:00") {
                    expect(parseEventDateTime("tomorrow 9am to 11am", relativeTo: now).flatMap { $0.end }.map { hour($0) }) == 11
                }
                it("'tomorrow 9am to 11am' start is on January 16") {
                    expect(parseEventDateTime("tomorrow 9am to 11am", relativeTo: now).map { day($0.start) }) == 16
                }
                it("'today 9:30am to 11am' start minute is 30") {
                    expect(parseEventDateTime("today 9:30am to 11am", relativeTo: now).map { minute($0.start) }) == 30
                }
                it("'today 9:30am to 11am' ends at 11:00") {
                    expect(parseEventDateTime("today 9:30am to 11am", relativeTo: now).flatMap { $0.end }.map { hour($0) }) == 11
                }
                it("'friday 2pm to 3pm' start is on January 16") {
                    expect(parseEventDateTime("friday 2pm to 3pm", relativeTo: now).map { day($0.start) }) == 16
                }
            }

            // MARK: Timed events — single time, 1-hour default duration

            context("timed events with a single time — 1-hour default duration") {
                it("'monday at 2pm' is not all-day") {
                    expect(parseEventDateTime("monday at 2pm", relativeTo: now)?.isAllDay) == false
                }
                it("'monday at 2pm' starts at hour 14") {
                    expect(parseEventDateTime("monday at 2pm", relativeTo: now).map { hour($0.start) }) == 14
                }
                it("'monday at 2pm' ends 1 hour after start") {
                    let result = parseEventDateTime("monday at 2pm", relativeTo: now)
                    let startH = result.map { hour($0.start) }
                    let endH   = result.flatMap { $0.end }.map { hour($0) }
                    expect(endH) == (startH.map { $0 + 1 })
                }
                it("time with no date part defaults to the reference date") {
                    expect(parseEventDateTime("2pm to 3pm", relativeTo: now).map { day($0.start) }) == 15
                }
            }

            // MARK: AM/PM edge cases

            context("AM/PM edge cases") {
                it("'12pm' resolves to hour 12 (noon)") {
                    expect(parseEventDateTime("today 12pm to 1pm", relativeTo: now).map { hour($0.start) }) == 12
                }
                it("'12am' resolves to hour 0 (midnight)") {
                    expect(parseEventDateTime("today 12am to 1am", relativeTo: now).map { hour($0.start) }) == 0
                }
                it("'2am' resolves to hour 2") {
                    expect(parseEventDateTime("today 2am to 3am", relativeTo: now).map { hour($0.start) }) == 2
                }
                it("input is case-insensitive for AM/PM") {
                    let lower = parseEventDateTime("today 2pm to 3pm", relativeTo: now).map { hour($0.start) }
                    let upper = parseEventDateTime("today 2PM to 3PM", relativeTo: now).map { hour($0.start) }
                    expect(lower) == upper
                }
            }

            // MARK: Invalid input

            context("invalid input") {
                it("returns nil for completely unrecognized input") {
                    expect(parseEventDateTime("banana", relativeTo: now)).to(beNil())
                }
                it("returns nil for empty string") {
                    expect(parseEventDateTime("", relativeTo: now)).to(beNil())
                }
                it("returns nil when the date part is unrecognizable") {
                    expect(parseEventDateTime("notadate 2pm to 3pm", relativeTo: now)).to(beNil())
                }
            }
        }
    }
}
