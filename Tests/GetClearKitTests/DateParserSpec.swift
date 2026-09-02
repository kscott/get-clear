// DateParserSpec.swift
//
// Tests for GetClearKit DateParser — natural language date string parsing.

import Foundation
import GetClearKit
import Testing

private let cal = Calendar.current

private func ymd(_ date: Date) -> DateComponents {
    cal.dateComponents([.year, .month, .day], from: date)
}

private func hm(_ date: Date) -> DateComponents {
    cal.dateComponents([.hour, .minute], from: date)
}

private func sameDay(_ a: Date, _ b: Date) -> Bool {
    cal.isDate(a, inSameDayAs: b)
}

@Suite("parseDate")
struct DateParserTests {
    @Suite("hasTime flag")
    struct HasTimeFlag {
        @Test("is false for a date-only string") func falseForDateOnly() {
            #expect(parseDate("tomorrow")?.hasTime == false)
        }

        @Test("is false for a weekday-only string") func falseForWeekdayOnly() {
            #expect(parseDate("friday")?.hasTime == false)
        }

        @Test("is false for month and day only") func falseForMonthDay() {
            #expect(parseDate("march 15")?.hasTime == false)
        }

        @Test("is true when a time is given alone") func trueForTimeAlone() {
            #expect(parseDate("3pm")?.hasTime == true)
        }

        @Test("is true for a date combined with time") func trueForDateAndTime() {
            #expect(parseDate("tomorrow 3pm")?.hasTime == true)
        }

        @Test("is true for a weekday combined with time") func trueForWeekdayAndTime() {
            #expect(parseDate("friday at 5pm")?.hasTime == true)
        }

        @Test("is true for a 24-hour time") func trueFor24Hour() {
            #expect(parseDate("14:30")?.hasTime == true)
        }
    }

    @Suite("hasDate flag")
    struct HasDateFlag {
        @Test("is false for a 12-hour time alone") func falseFor12Hour() {
            #expect(parseDate("3pm")?.hasDate == false)
        }

        @Test("is false for a 12-hour time with minutes") func falseFor12HourMinutes() {
            #expect(parseDate("8:30pm")?.hasDate == false)
        }

        @Test("is false for a 24-hour time alone") func falseFor24Hour() {
            #expect(parseDate("14:30")?.hasDate == false)
        }

        @Test("is true for a relative day") func trueForRelativeDay() {
            #expect(parseDate("tomorrow")?.hasDate == true)
        }

        @Test("is true for a weekday name") func trueForWeekday() {
            #expect(parseDate("friday")?.hasDate == true)
        }

        @Test("is true for month and day") func trueForMonthDay() {
            #expect(parseDate("march 15")?.hasDate == true)
        }

        @Test("is true for an ISO date") func trueForIso() {
            #expect(parseDate("2026-03-15")?.hasDate == true)
        }

        @Test("is true for a weekday combined with time") func trueForWeekdayAndTime() {
            #expect(parseDate("friday at 5pm")?.hasDate == true)
        }

        @Test("is true for a relative day combined with time") func trueForRelativeAndTime() {
            #expect(parseDate("tomorrow 3pm")?.hasDate == true)
        }
    }

    @Suite("relative days")
    struct RelativeDays {
        @Test("'today' resolves to today")
        func todayResolves() {
            #expect(parseDate("today").map { sameDay($0.date, Date()) } == true)
        }

        @Test("'tomorrow' resolves to tomorrow")
        func tomorrowResolves() throws {
            let expected = try #require(cal.date(byAdding: .day, value: 1, to: Date()))
            #expect(parseDate("tomorrow").map { sameDay($0.date, expected) } == true)
        }
    }

    @Suite("weekday names")
    struct WeekdayNames {
        let days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]

        @Test("each weekday resolves to a future date")
        func eachWeekdayFuture() {
            for day in days {
                #expect(parseDate(day).map { $0.date > Date() } == true)
            }
        }

        @Test("each weekday is within 7 days from today")
        func eachWeekdayWithinSevenDays() {
            for day in days {
                guard let pd = parseDate(day) else {
                    Issue.record("parseDate(\(day)) returned nil")
                    continue
                }
                let diff = cal.dateComponents([.day],
                                              from: cal.startOfDay(for: Date()),
                                              to: cal.startOfDay(for: pd.date)).day ?? 99
                #expect(diff <= 7)
            }
        }
    }

    @Suite("'next' and 'this' prefix")
    struct NextAndThisPrefix {
        @Test("'next friday' resolves to the same date as 'friday'") func nextFriday() {
            #expect(parseDate("next friday")?.date == parseDate("friday")?.date)
        }

        @Test("'this friday' resolves to the same date as 'friday'") func thisFriday() {
            #expect(parseDate("this friday")?.date == parseDate("friday")?.date)
        }

        @Test("'next monday' resolves to the same date as 'monday'") func nextMonday() {
            #expect(parseDate("next monday")?.date == parseDate("monday")?.date)
        }
    }

    @Suite("month and day")
    struct MonthAndDay {
        @Test("'march 15' resolves to month 3") func month() {
            #expect(parseDate("march 15").map { cal.component(.month, from: $0.date) } == 3)
        }

        @Test("'march 15' resolves to day 15") func day() {
            #expect(parseDate("march 15").map { cal.component(.day, from: $0.date) } == 15)
        }

        @Test("'january 1' rolls to the future when in the past") func rollsForward() {
            #expect(parseDate("january 1").map { $0.date >= Date() } == true)
        }
    }

    @Suite("month, day, and year")
    struct MonthDayYear {
        @Test("'march 10 2027' resolves to year 2027") func year() {
            #expect(parseDate("march 10 2027").map { ymd($0.date).year } == 2027)
        }

        @Test("'march 10 2027' resolves to month 3") func month() {
            #expect(parseDate("march 10 2027").map { ymd($0.date).month } == 3)
        }

        @Test("'march 10 2027' resolves to day 10") func day() {
            #expect(parseDate("march 10 2027").map { ymd($0.date).day } == 10)
        }

        @Test("'march 10, 2027' with comma resolves correctly") func comma() {
            #expect(parseDate("march 10, 2027").map { ymd($0.date).year } == 2027)
        }

        @Test("'10 march 2027' day-first order resolves correctly") func dayFirst() {
            #expect(parseDate("10 march 2027").map { ymd($0.date).year } == 2027)
        }

        @Test("two-digit year expands to the 2000s") func twoDigitYear() {
            #expect(parseDate("january 1 28").map { ymd($0.date).year } == 2028)
        }
    }

    @Suite("ISO date format")
    struct IsoDateFormat {
        @Test("resolves to the correct year") func year() {
            #expect(parseDate("2026-03-15").map { ymd($0.date).year } == 2026)
        }

        @Test("resolves to the correct month") func month() {
            #expect(parseDate("2026-03-15").map { ymd($0.date).month } == 3)
        }

        @Test("resolves to the correct day") func day() {
            #expect(parseDate("2026-03-15").map { ymd($0.date).day } == 15)
        }
    }

    @Suite("short numeric date format")
    struct ShortNumericDateFormat {
        @Test("'3/15' resolves to month 3") func slashMonth() {
            #expect(parseDate("3/15").map { ymd($0.date).month } == 3)
        }

        @Test("'3/15' resolves to day 15") func slashDay() {
            #expect(parseDate("3/15").map { ymd($0.date).day } == 15)
        }

        @Test("'3-15' resolves to month 3") func dashMonth() {
            #expect(parseDate("3-15").map { ymd($0.date).month } == 3)
        }

        @Test("'3-15' resolves to day 15") func dashDay() {
            #expect(parseDate("3-15").map { ymd($0.date).day } == 15)
        }

        @Test("past month/day rolls to the future") func rollsForward() {
            #expect(parseDate("1/1").map { $0.date >= Date() } == true)
        }

        @Test("'3/10/2027' resolves to year 2027") func fullYear() {
            #expect(parseDate("3/10/2027").map { ymd($0.date).year } == 2027)
        }

        @Test("'3/10/2027' resolves to month 3") func fullMonth() {
            #expect(parseDate("3/10/2027").map { ymd($0.date).month } == 3)
        }

        @Test("'3/10/2027' resolves to day 10") func fullDay() {
            #expect(parseDate("3/10/2027").map { ymd($0.date).day } == 10)
        }

        @Test("two-digit year in US M/D/YY format expands to the 2000s") func usTwoDigit() {
            #expect(parseDate("3/10/27").map { ymd($0.date).year } == 2027)
        }
    }

    @Suite("time parsing")
    struct TimeParsing {
        @Test("'3pm' is hour 15") func threePm() {
            #expect(parseDate("3pm").map { hm($0.date).hour } == 15)
        }

        @Test("'10am' is hour 10") func tenAm() {
            #expect(parseDate("10am").map { hm($0.date).hour } == 10)
        }

        @Test("'12pm' is noon (hour 12)") func noon() {
            #expect(parseDate("12pm").map { hm($0.date).hour } == 12)
        }

        @Test("'12am' is midnight (hour 0)") func midnight() {
            #expect(parseDate("12am").map { hm($0.date).hour } == 0)
        }

        @Test("'14:30' is hour 14") func military1() {
            #expect(parseDate("14:30").map { hm($0.date).hour } == 14)
        }

        @Test("'14:30' is minute 30") func military2() {
            #expect(parseDate("14:30").map { hm($0.date).minute } == 30)
        }

        @Test("'2:45pm' is hour 14") func pmHour() {
            #expect(parseDate("2:45pm").map { hm($0.date).hour } == 14)
        }

        @Test("'2:45pm' is minute 45") func pmMinute() {
            #expect(parseDate("2:45pm").map { hm($0.date).minute } == 45)
        }

        @Test("'8:30pm' is hour 20") func eveningHour() {
            #expect(parseDate("8:30pm").map { hm($0.date).hour } == 20)
        }

        @Test("'8:30pm' is minute 30") func eveningMinute() {
            #expect(parseDate("8:30pm").map { hm($0.date).minute } == 30)
        }
    }

    @Suite("date combined with time")
    struct DateCombinedWithTime {
        @Test("'tomorrow 3pm' resolves to tomorrow")
        func tomorrowResolves() throws {
            let tomorrow = try #require(cal.date(byAdding: .day, value: 1, to: Date()))
            #expect(parseDate("tomorrow 3pm").map { sameDay($0.date, tomorrow) } == true)
        }

        @Test("'tomorrow 3pm' is at hour 15") func tomorrowHour() {
            #expect(parseDate("tomorrow 3pm").map { hm($0.date).hour } == 15)
        }

        @Test("'friday at 5pm' resolves to a future date") func fridayFuture() {
            #expect(parseDate("friday at 5pm").map { $0.date > Date() } == true)
        }

        @Test("'friday at 5pm' is at hour 17") func fridayHour() {
            #expect(parseDate("friday at 5pm").map { hm($0.date).hour } == 17)
        }

        @Test("'march 15 9am' resolves to month 3") func marchMonth() {
            #expect(parseDate("march 15 9am").map { ymd($0.date).month } == 3)
        }

        @Test("'march 15 9am' resolves to day 15") func marchDay() {
            #expect(parseDate("march 15 9am").map { ymd($0.date).day } == 15)
        }

        @Test("'march 15 9am' is at hour 9") func marchHour() {
            #expect(parseDate("march 15 9am").map { hm($0.date).hour } == 9)
        }

        @Test("'monday at 8am' has hasDate true") func mondayHasDate() {
            #expect(parseDate("monday at 8am")?.hasDate == true)
        }

        @Test("'monday at 8am' has hasTime true") func mondayHasTime() {
            #expect(parseDate("monday at 8am")?.hasTime == true)
        }

        @Test("'monday at 8am' is at hour 8") func mondayHour() {
            #expect(parseDate("monday at 8am").map { hm($0.date).hour } == 8)
        }
    }

    @Suite("abbreviated month names")
    struct AbbreviatedMonthNames {
        @Test("'mar 20, 2026' resolves successfully") func marResolves() {
            #expect(parseDate("mar 20, 2026") != nil)
        }

        @Test("'mar 20, 2026' resolves to month 3") func marMonth() {
            #expect(parseDate("mar 20, 2026").map { ymd($0.date).month } == 3)
        }

        @Test("'mar 20, 2026' resolves to day 20") func marDay() {
            #expect(parseDate("mar 20, 2026").map { ymd($0.date).day } == 20)
        }

        @Test("'mar 20, 2026' resolves to year 2026") func marYear() {
            #expect(parseDate("mar 20, 2026").map { ymd($0.date).year } == 2026)
        }

        @Test("'jan 5' resolves successfully") func janResolves() {
            #expect(parseDate("jan 5") != nil)
        }

        @Test("'jan 5' resolves to month 1") func janMonth() {
            #expect(parseDate("jan 5").map { ymd($0.date).month } == 1)
        }

        @Test("'jan 5' resolves to day 5") func janDay() {
            #expect(parseDate("jan 5").map { ymd($0.date).day } == 5)
        }

        @Test("'dec 31, 2027' resolves successfully") func decResolves() {
            #expect(parseDate("dec 31, 2027") != nil)
        }

        @Test("'dec 31, 2027' resolves to month 12") func decMonth() {
            #expect(parseDate("dec 31, 2027").map { ymd($0.date).month } == 12)
        }

        @Test("'dec 31, 2027' resolves to year 2027") func decYear() {
            #expect(parseDate("dec 31, 2027").map { ymd($0.date).year } == 2027)
        }
    }

    @Suite("invalid input")
    struct InvalidInput {
        @Test("returns nil for unrecognized input") func nilForUnrecognized() {
            #expect(parseDate("banana") == nil)
        }

        @Test("returns nil for multi-word nonsense") func nilForNonsense() {
            #expect(parseDate("foo bar baz") == nil)
        }
    }
}

@Suite("formatDate")
struct FormatDateTests {
    let d = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 14, minute: 30))!

    @Test("date-only format is non-empty")
    func dateOnlyNonEmpty() {
        #expect(!formatDate(d, showTime: false).isEmpty)
    }

    @Test("date-only format does not contain the time")
    func dateOnlyNoTime() {
        #expect(!formatDate(d, showTime: false).contains("2:30"))
    }

    @Test("date+time format is non-empty")
    func dateTimeNonEmpty() {
        #expect(!formatDate(d, showTime: true).isEmpty)
    }

    @Test("date+time format is longer than date-only")
    func dateTimeLonger() {
        #expect(formatDate(d, showTime: true).count > formatDate(d, showTime: false).count)
    }
}
