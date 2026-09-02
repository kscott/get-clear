// RangeParserSpec.swift
//
// Tests for GetClearKit RangeParser — date range string parsing into ParsedRange.

import Foundation
import GetClearKit
import Testing

private let cal = Calendar.current

private func sameDay(_ a: Date, _ b: Date) -> Bool {
    cal.isDate(a, inSameDayAs: b)
}

@Suite("parseRange")
struct RangeParserTests {
    @Suite("single-day shorthands")
    struct SingleDayShorthands {
        @Test("'today' resolves to today")
        func todayResolvesToToday() {
            #expect(parseRange("today").map { sameDay($0.start, Date()) } == true)
        }

        @Test("'today' is a single-day range")
        func todayIsSingleDay() {
            #expect(parseRange("today")?.isSingleDay == true)
        }

        @Test("'tomorrow' resolves to tomorrow")
        func tomorrowResolvesToTomorrow() throws {
            let expected = try #require(cal.date(byAdding: .day, value: 1, to: Date()))
            #expect(parseRange("tomorrow").map { sameDay($0.start, expected) } == true)
        }

        @Test("'tomorrow' is a single-day range")
        func tomorrowIsSingleDay() {
            #expect(parseRange("tomorrow")?.isSingleDay == true)
        }

        @Test("'yesterday' resolves to yesterday")
        func yesterdayResolvesToYesterday() throws {
            let expected = try #require(cal.date(byAdding: .day, value: -1, to: Date()))
            #expect(parseRange("yesterday").map { sameDay($0.start, expected) } == true)
        }

        @Test("'yesterday' is a single-day range")
        func yesterdayIsSingleDay() {
            #expect(parseRange("yesterday")?.isSingleDay == true)
        }
    }

    @Suite("weekday names")
    struct WeekdayNames {
        let days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]

        @Test("each weekday resolves to a future or current date")
        func eachWeekdayFutureOrCurrent() {
            for day in days {
                #expect(parseRange(day).map { $0.start >= cal.startOfDay(for: Date()) } == true)
            }
        }

        @Test("each weekday is a single-day range")
        func eachWeekdaySingleDay() {
            for day in days {
                #expect(parseRange(day)?.isSingleDay == true)
            }
        }

        @Test("'next friday' resolves to the same date as 'friday'")
        func nextFridayEqualsFriday() {
            #expect(parseRange("next friday")?.start == parseRange("friday")?.start)
        }
    }

    @Suite("specific dates — month and day")
    struct MonthAndDay {
        @Test("'march 15' resolves to month 3")
        func march15Month() {
            #expect(parseRange("march 15").map { cal.component(.month, from: $0.start) } == 3)
        }

        @Test("'march 15' resolves to day 15")
        func march15Day() {
            #expect(parseRange("march 15").map { cal.component(.day, from: $0.start) } == 15)
        }

        @Test("'march 15' is a single-day range")
        func march15SingleDay() {
            #expect(parseRange("march 15")?.isSingleDay == true)
        }

        @Test("past month+day rolls forward to the future")
        func pastMonthDayRollsForward() {
            #expect(parseRange("march 15").map { $0.start >= cal.startOfDay(for: Date()) } == true)
        }
    }

    @Suite("specific dates — ISO")
    struct IsoFormat {
        @Test("'2026-03-15' resolves to year 2026")
        func isoYear() {
            #expect(parseRange("2026-03-15").map { cal.component(.year, from: $0.start) } == 2026)
        }

        @Test("'2026-03-15' resolves to month 3")
        func isoMonth() {
            #expect(parseRange("2026-03-15").map { cal.component(.month, from: $0.start) } == 3)
        }

        @Test("'2026-03-15' resolves to day 15")
        func isoDay() {
            #expect(parseRange("2026-03-15").map { cal.component(.day, from: $0.start) } == 15)
        }

        @Test("'2026-03-15' is a single-day range")
        func isoSingleDay() {
            #expect(parseRange("2026-03-15")?.isSingleDay == true)
        }
    }

    @Suite("specific dates — short numeric")
    struct ShortNumericFormat {
        @Test("'3/15' resolves to month 3")
        func shortMonth() {
            #expect(parseRange("3/15").map { cal.component(.month, from: $0.start) } == 3)
        }

        @Test("'3/15' resolves to day 15")
        func shortDay() {
            #expect(parseRange("3/15").map { cal.component(.day, from: $0.start) } == 15)
        }

        @Test("'3/15' is a single-day range")
        func shortSingleDay() {
            #expect(parseRange("3/15")?.isSingleDay == true)
        }
    }

    @Suite("week spans")
    struct WeekSpans {
        @Test("'week' is not a single-day range")
        func weekNotSingleDay() {
            #expect(parseRange("week")?.isSingleDay == false)
        }

        @Test("'week' start is on or before today")
        func weekStartBeforeToday() {
            #expect(parseRange("week").map { $0.start <= Date() } == true)
        }

        @Test("'week' end is on or after today")
        func weekEndAfterToday() {
            #expect(parseRange("week").map { $0.end >= Date() } == true)
        }

        @Test("'this week' equals 'week'")
        func thisWeekEqualsWeek() {
            #expect(parseRange("this week")?.start == parseRange("week")?.start)
        }

        @Test("'next week' starts after this week ends")
        func nextWeekAfterThisWeek() {
            guard let w = parseRange("week"), let nw = parseRange("next week") else { return }
            #expect(nw.start > w.end)
        }

        @Test("'last week' ends before this week starts")
        func lastWeekBeforeThisWeek() {
            guard let w = parseRange("week"), let lw = parseRange("last week") else { return }
            #expect(lw.end < w.start)
        }
    }

    @Suite("month spans")
    struct MonthSpans {
        @Test("'month' is not a single-day range")
        func monthNotSingleDay() {
            #expect(parseRange("month")?.isSingleDay == false)
        }

        @Test("'month' starts on the 1st")
        func monthStartsOnFirst() {
            #expect(parseRange("month").map { cal.component(.day, from: $0.start) } == 1)
        }

        @Test("'this month' equals 'month'")
        func thisMonthEqualsMonth() {
            #expect(parseRange("this month")?.start == parseRange("month")?.start)
        }

        @Test("'next month' starts after this month ends")
        func nextMonthAfterThisMonth() {
            guard let m = parseRange("month"), let nm = parseRange("next month") else { return }
            #expect(nm.start > m.end)
        }

        @Test("'last month' ends before this month starts")
        func lastMonthBeforeThisMonth() {
            guard let m = parseRange("month"), let lm = parseRange("last month") else { return }
            #expect(lm.end < m.start)
        }
    }

    @Suite("N-day windows")
    struct NDayWindows {
        @Test("'7d' is not a single-day range")
        func sevenDNotSingleDay() {
            #expect(parseRange("7d")?.isSingleDay == false)
        }

        @Test("'7d' starts today")
        func sevenDStartsToday() {
            #expect(parseRange("7d").map { sameDay($0.start, Date()) } == true)
        }

        @Test("'7d' spans 7 calendar days")
        func sevenDSpansSevenDays() {
            guard let r = parseRange("7d") else { return }
            let days = cal.dateComponents([.day], from: r.start, to: r.end).day ?? 0
            #expect(days == 6)
        }

        @Test("'1d' is a single-day range")
        func oneDSingleDay() {
            #expect(parseRange("1d")?.isSingleDay == true)
        }

        @Test("'30d' is not a single-day range")
        func thirtyDNotSingleDay() {
            #expect(parseRange("30d")?.isSingleDay == false)
        }
    }

    @Suite("explicit ranges")
    struct ExplicitRanges {
        @Test("'march 15 to march 20' is not a single-day range")
        func explicitNotSingleDay() {
            #expect(parseRange("march 15 to march 20")?.isSingleDay == false)
        }

        @Test("'march 15 to march 20' starts on day 15")
        func explicitStartsDay15() {
            #expect(parseRange("march 15 to march 20").map { cal.component(.day, from: $0.start) } == 15)
        }

        @Test("'march 15 to march 20' ends on day 20")
        func explicitEndsDay20() {
            #expect(parseRange("march 15 to march 20").map { cal.component(.day, from: $0.end) } == 20)
        }

        @Test("'today to friday' starts today")
        func todayToFridayStartsToday() {
            #expect(parseRange("today to friday").map { sameDay($0.start, Date()) } == true)
        }
    }

    @Suite("range boundary times")
    struct RangeBoundaryTimes {
        @Test("single-day range starts at midnight")
        func startsAtMidnight() {
            guard let r = parseRange("today") else { return }
            let comps = cal.dateComponents([.hour, .minute, .second], from: r.start)
            #expect(comps.hour == 0 && comps.minute == 0 && comps.second == 0)
        }

        @Test("single-day range ends at 23:59:59")
        func endsAtEndOfDay() {
            guard let r = parseRange("today") else { return }
            let comps = cal.dateComponents([.hour, .minute, .second], from: r.end)
            #expect(comps.hour == 23 && comps.minute == 59 && comps.second == 59)
        }
    }

    @Suite("invalid input")
    struct InvalidInput {
        @Test("returns nil for unrecognized input")
        func nilForUnrecognized() {
            #expect(parseRange("banana") == nil)
        }

        @Test("returns nil for empty string")
        func nilForEmpty() {
            #expect(parseRange("") == nil)
        }
    }
}

@Suite("parseSingleDate")
struct ParseSingleDateTests {
    @Test("'today' resolves to today")
    func todayResolves() {
        #expect(parseSingleDate("today", cal: cal, now: Date()).map { sameDay($0, Date()) } == true)
    }

    @Test("'tomorrow' resolves to tomorrow")
    func tomorrowResolves() throws {
        let expected = try #require(cal.date(byAdding: .day, value: 1, to: Date()))
        #expect(parseSingleDate("tomorrow", cal: cal, now: Date()).map { sameDay($0, expected) } == true)
    }

    @Test("'friday' resolves to a date")
    func fridayResolves() {
        #expect(parseSingleDate("friday", cal: cal, now: Date()) != nil)
    }

    @Test("'march 15' resolves to a date")
    func march15Resolves() {
        #expect(parseSingleDate("march 15", cal: cal, now: Date()) != nil)
    }

    @Test("returns nil for unrecognized input")
    func nilForUnrecognized() {
        #expect(parseSingleDate("banana", cal: cal, now: Date()) == nil)
    }
}
