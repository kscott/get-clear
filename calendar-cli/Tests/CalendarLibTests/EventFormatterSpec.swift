// EventFormatterSpec.swift
// Tests for CalendarLib EventFormatter — event line and relative label formatting.

import Quick
import Nimble
import Foundation
import CalendarLib

final class EventFormatterSpec: QuickSpec {
    override class func spec() {
        let cal = Calendar.current
        // Fixed reference: Thursday January 15, 2026 at noon
        let now: Date = {
            var c = DateComponents()
            c.year = 2026; c.month = 1; c.day = 15
            c.hour = 12; c.minute = 0; c.second = 0
            return cal.date(from: c)!
        }()

        func makeDate(hour: Int, minute: Int = 0, dayOffset: Int = 0) -> Date {
            var c = DateComponents()
            c.year = 2026; c.month = 1; c.day = 15 + dayOffset
            c.hour = hour; c.minute = minute; c.second = 0
            return cal.date(from: c)!
        }

        func timedEvent(
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

        func allDayEvent(
            title: String = "Holiday",
            dayOffset: Int = 0,
            location: String? = nil,
            calendarTitle: String = "Home"
        ) -> EventItem {
            let start = cal.startOfDay(for: makeDate(hour: 0, dayOffset: dayOffset))
            let end   = cal.date(byAdding: DateComponents(day: 1, second: -1), to: start)
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

        describe("eventLine") {

            context("timed events") {
                it("contains the event title") {
                    let line = eventLine(for: timedEvent(title: "Team Sync"))
                    expect(line).to(contain("Team Sync"))
                }
                it("does not contain 'All day'") {
                    let line = eventLine(for: timedEvent())
                    expect(line).toNot(contain("All day"))
                }
                it("contains the start time") {
                    let event = timedEvent(startHour: 14, endHour: 15)
                    let line  = eventLine(for: event)
                    expect(line).to(contain(formatEventTime(event.startDate)))
                }
                it("contains the end time") {
                    let event = timedEvent(startHour: 14, endHour: 15)
                    let line  = eventLine(for: event)
                    expect(line).to(contain(formatEventTime(event.endDate!)))
                }
            }

            context("all-day events") {
                it("contains 'All day'") {
                    let line = eventLine(for: allDayEvent())
                    expect(line).to(contain("All day"))
                }
                it("contains the event title") {
                    let line = eventLine(for: allDayEvent(title: "New Year"))
                    expect(line).to(contain("New Year"))
                }
                it("does not contain a time") {
                    let event = allDayEvent()
                    let line  = eventLine(for: event)
                    expect(line).toNot(contain(formatEventTime(event.startDate)))
                }
            }

            context("location") {
                it("appends location after ' · ' separator") {
                    let line = eventLine(for: timedEvent(location: "Zoom"))
                    expect(line).to(contain(" · Zoom"))
                }
                it("uses only the first line of a multi-line location") {
                    let line = eventLine(for: timedEvent(location: "123 Main St\nFloor 2"))
                    expect(line).to(contain("123 Main St"))
                }
                it("omits subsequent lines of a multi-line location") {
                    let line = eventLine(for: timedEvent(location: "123 Main St\nFloor 2"))
                    expect(line).toNot(contain("Floor 2"))
                }
                it("truncates location longer than 50 characters") {
                    let long = String(repeating: "A", count: 60)
                    let line = eventLine(for: timedEvent(location: long))
                    expect(line).to(contain("…"))
                    expect(line).toNot(contain(long))
                }
                it("does not truncate a location of exactly 50 characters") {
                    let exact = String(repeating: "B", count: 50)
                    let line  = eventLine(for: timedEvent(location: exact))
                    expect(line).toNot(contain("…"))
                }
                it("omits ' · ' when location is nil") {
                    let line = eventLine(for: timedEvent(location: nil))
                    expect(line).toNot(contain(" · "))
                }
                it("omits ' · ' when location is empty") {
                    let line = eventLine(for: timedEvent(location: ""))
                    expect(line).toNot(contain(" · "))
                }
            }

        }

        // MARK: - nextRelativeLabel

        describe("nextRelativeLabel") {
            context("today") {
                it("returns a label starting with 'Today' for the reference date") {
                    let label = nextRelativeLabel(for: now, relativeTo: now)
                    expect(label).to(beginWith("Today"))
                }
            }

            context("tomorrow") {
                it("returns a label starting with 'Tomorrow' for one day ahead") {
                    let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
                    let label    = nextRelativeLabel(for: tomorrow, relativeTo: now)
                    expect(label).to(beginWith("Tomorrow"))
                }
            }

            context("within 7 days") {
                it("returns an abbreviated day name for a date 5 days out") {
                    // Jan 20 2026 is a Tuesday — 5 days after Jan 15
                    let tuesday = cal.date(byAdding: .day, value: 5, to: now)!
                    let label   = nextRelativeLabel(for: tuesday, relativeTo: now)
                    expect(label).to(beginWith("Tue"))
                }
                it("does not return 'Today' or 'Tomorrow' for a date within 7 days") {
                    let threeDays = cal.date(byAdding: .day, value: 3, to: now)!
                    let label     = nextRelativeLabel(for: threeDays, relativeTo: now)
                    expect(label).toNot(beginWith("Today"))
                    expect(label).toNot(beginWith("Tomorrow"))
                }
            }

            context("7 or more days away") {
                it("returns a month+day label for a date 10 days out") {
                    // Jan 25 2026 — 10 days after Jan 15
                    let tenDays = cal.date(byAdding: .day, value: 10, to: now)!
                    let label   = nextRelativeLabel(for: tenDays, relativeTo: now)
                    expect(label).to(beginWith("Jan 25"))
                }
                it("does not use an abbreviated day name for a date 10 days out") {
                    let tenDays = cal.date(byAdding: .day, value: 10, to: now)!
                    let label   = nextRelativeLabel(for: tenDays, relativeTo: now)
                    expect(label).toNot(beginWith("Sun"))
                }
            }
        }
    }
}
