// DateParserSpec.swift
//
// Tests for GetClearKit DateParser — natural language date string parsing.

import Quick
import Nimble
import Foundation
import GetClearKit

final class DateParserSpec: QuickSpec {
    override class func spec() {
        let cal = Calendar.current

        func ymd(_ date: Date) -> DateComponents {
            cal.dateComponents([.year, .month, .day], from: date)
        }
        func hm(_ date: Date) -> DateComponents {
            cal.dateComponents([.hour, .minute], from: date)
        }
        func sameDay(_ a: Date, _ b: Date) -> Bool {
            cal.isDate(a, inSameDayAs: b)
        }

        describe("parseDate") {
            context("hasTime flag") {
                it("is false for a date-only string") {
                    expect(parseDate("tomorrow")?.hasTime) == false
                }
                it("is false for a weekday-only string") {
                    expect(parseDate("friday")?.hasTime) == false
                }
                it("is false for month and day only") {
                    expect(parseDate("march 15")?.hasTime) == false
                }
                it("is true when a time is given alone") {
                    expect(parseDate("3pm")?.hasTime) == true
                }
                it("is true for a date combined with time") {
                    expect(parseDate("tomorrow 3pm")?.hasTime) == true
                }
                it("is true for a weekday combined with time") {
                    expect(parseDate("friday at 5pm")?.hasTime) == true
                }
                it("is true for a 24-hour time") {
                    expect(parseDate("14:30")?.hasTime) == true
                }
            }

            context("hasDate flag") {
                it("is false for a 12-hour time alone") {
                    expect(parseDate("3pm")?.hasDate) == false
                }
                it("is false for a 12-hour time with minutes") {
                    expect(parseDate("8:30pm")?.hasDate) == false
                }
                it("is false for a 24-hour time alone") {
                    expect(parseDate("14:30")?.hasDate) == false
                }
                it("is true for a relative day") {
                    expect(parseDate("tomorrow")?.hasDate) == true
                }
                it("is true for a weekday name") {
                    expect(parseDate("friday")?.hasDate) == true
                }
                it("is true for month and day") {
                    expect(parseDate("march 15")?.hasDate) == true
                }
                it("is true for an ISO date") {
                    expect(parseDate("2026-03-15")?.hasDate) == true
                }
                it("is true for a weekday combined with time") {
                    expect(parseDate("friday at 5pm")?.hasDate) == true
                }
                it("is true for a relative day combined with time") {
                    expect(parseDate("tomorrow 3pm")?.hasDate) == true
                }
            }

            context("relative days") {
                it("'today' resolves to today") {
                    expect(parseDate("today").map { sameDay($0.date, Date()) }) == true
                }
                it("'tomorrow' resolves to tomorrow") {
                    let expected = cal.date(byAdding: .day, value: 1, to: Date())!
                    expect(parseDate("tomorrow").map { sameDay($0.date, expected) }) == true
                }
            }

            context("weekday names") {
                let days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]

                it("each weekday resolves to a future date") {
                    for day in days {
                        expect(parseDate(day).map { $0.date > Date() }) == true
                    }
                }
                it("each weekday is within 7 days from today") {
                    for day in days {
                        guard let pd = parseDate(day) else { fail("parseDate(\(day)) returned nil"); continue }
                        let diff = cal.dateComponents([.day],
                            from: cal.startOfDay(for: Date()),
                            to: cal.startOfDay(for: pd.date)).day ?? 99
                        expect(diff) <= 7
                    }
                }
            }

            context("'next' and 'this' prefix") {
                it("'next friday' resolves to the same date as 'friday'") {
                    expect(parseDate("next friday")?.date) == parseDate("friday")?.date
                }
                it("'this friday' resolves to the same date as 'friday'") {
                    expect(parseDate("this friday")?.date) == parseDate("friday")?.date
                }
                it("'next monday' resolves to the same date as 'monday'") {
                    expect(parseDate("next monday")?.date) == parseDate("monday")?.date
                }
            }

            context("month and day") {
                it("'march 15' resolves to month 3") {
                    expect(parseDate("march 15").map { cal.component(.month, from: $0.date) }) == 3
                }
                it("'march 15' resolves to day 15") {
                    expect(parseDate("march 15").map { cal.component(.day, from: $0.date) }) == 15
                }
                it("'january 1' rolls to the future when in the past") {
                    expect(parseDate("january 1").map { $0.date >= Date() }) == true
                }
            }

            context("month, day, and year") {
                it("'march 10 2027' resolves to year 2027") {
                    expect(parseDate("march 10 2027").map { ymd($0.date).year }) == 2027
                }
                it("'march 10 2027' resolves to month 3") {
                    expect(parseDate("march 10 2027").map { ymd($0.date).month }) == 3
                }
                it("'march 10 2027' resolves to day 10") {
                    expect(parseDate("march 10 2027").map { ymd($0.date).day }) == 10
                }
                it("'march 10, 2027' with comma resolves correctly") {
                    expect(parseDate("march 10, 2027").map { ymd($0.date).year }) == 2027
                }
                it("'10 march 2027' day-first order resolves correctly") {
                    expect(parseDate("10 march 2027").map { ymd($0.date).year }) == 2027
                }
                it("two-digit year expands to the 2000s") {
                    expect(parseDate("january 1 28").map { ymd($0.date).year }) == 2028
                }
            }

            context("ISO date format") {
                it("resolves to the correct year") {
                    expect(parseDate("2026-03-15").map { ymd($0.date).year }) == 2026
                }
                it("resolves to the correct month") {
                    expect(parseDate("2026-03-15").map { ymd($0.date).month }) == 3
                }
                it("resolves to the correct day") {
                    expect(parseDate("2026-03-15").map { ymd($0.date).day }) == 15
                }
            }

            context("short numeric date format") {
                it("'3/15' resolves to month 3") {
                    expect(parseDate("3/15").map { ymd($0.date).month }) == 3
                }
                it("'3/15' resolves to day 15") {
                    expect(parseDate("3/15").map { ymd($0.date).day }) == 15
                }
                it("'3-15' resolves to month 3") {
                    expect(parseDate("3-15").map { ymd($0.date).month }) == 3
                }
                it("'3-15' resolves to day 15") {
                    expect(parseDate("3-15").map { ymd($0.date).day }) == 15
                }
                it("past month/day rolls to the future") {
                    expect(parseDate("1/1").map { $0.date >= Date() }) == true
                }
                it("'3/10/2027' resolves to year 2027") {
                    expect(parseDate("3/10/2027").map { ymd($0.date).year }) == 2027
                }
                it("'3/10/2027' resolves to month 3") {
                    expect(parseDate("3/10/2027").map { ymd($0.date).month }) == 3
                }
                it("'3/10/2027' resolves to day 10") {
                    expect(parseDate("3/10/2027").map { ymd($0.date).day }) == 10
                }
                it("two-digit year in US M/D/YY format expands to the 2000s") {
                    expect(parseDate("3/10/27").map { ymd($0.date).year }) == 2027
                }
            }

            context("time parsing") {
                it("'3pm' is hour 15") {
                    expect(parseDate("3pm").map { hm($0.date).hour }) == 15
                }
                it("'10am' is hour 10") {
                    expect(parseDate("10am").map { hm($0.date).hour }) == 10
                }
                it("'12pm' is noon (hour 12)") {
                    expect(parseDate("12pm").map { hm($0.date).hour }) == 12
                }
                it("'12am' is midnight (hour 0)") {
                    expect(parseDate("12am").map { hm($0.date).hour }) == 0
                }
                it("'14:30' is hour 14") {
                    expect(parseDate("14:30").map { hm($0.date).hour }) == 14
                }
                it("'14:30' is minute 30") {
                    expect(parseDate("14:30").map { hm($0.date).minute }) == 30
                }
                it("'2:45pm' is hour 14") {
                    expect(parseDate("2:45pm").map { hm($0.date).hour }) == 14
                }
                it("'2:45pm' is minute 45") {
                    expect(parseDate("2:45pm").map { hm($0.date).minute }) == 45
                }
                it("'8:30pm' is hour 20") {
                    expect(parseDate("8:30pm").map { hm($0.date).hour }) == 20
                }
                it("'8:30pm' is minute 30") {
                    expect(parseDate("8:30pm").map { hm($0.date).minute }) == 30
                }
            }

            context("date combined with time") {
                it("'tomorrow 3pm' resolves to tomorrow") {
                    let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
                    expect(parseDate("tomorrow 3pm").map { sameDay($0.date, tomorrow) }) == true
                }
                it("'tomorrow 3pm' is at hour 15") {
                    expect(parseDate("tomorrow 3pm").map { hm($0.date).hour }) == 15
                }
                it("'friday at 5pm' resolves to a future date") {
                    expect(parseDate("friday at 5pm").map { $0.date > Date() }) == true
                }
                it("'friday at 5pm' is at hour 17") {
                    expect(parseDate("friday at 5pm").map { hm($0.date).hour }) == 17
                }
                it("'march 15 9am' resolves to month 3") {
                    expect(parseDate("march 15 9am").map { ymd($0.date).month }) == 3
                }
                it("'march 15 9am' resolves to day 15") {
                    expect(parseDate("march 15 9am").map { ymd($0.date).day }) == 15
                }
                it("'march 15 9am' is at hour 9") {
                    expect(parseDate("march 15 9am").map { hm($0.date).hour }) == 9
                }
                it("'monday at 8am' has hasDate true") {
                    expect(parseDate("monday at 8am")?.hasDate) == true
                }
                it("'monday at 8am' has hasTime true") {
                    expect(parseDate("monday at 8am")?.hasTime) == true
                }
                it("'monday at 8am' is at hour 8") {
                    expect(parseDate("monday at 8am").map { hm($0.date).hour }) == 8
                }
            }

            context("abbreviated month names") {
                it("'mar 20, 2026' resolves successfully") {
                    expect(parseDate("mar 20, 2026")).toNot(beNil())
                }
                it("'mar 20, 2026' resolves to month 3") {
                    expect(parseDate("mar 20, 2026").map { ymd($0.date).month }) == 3
                }
                it("'mar 20, 2026' resolves to day 20") {
                    expect(parseDate("mar 20, 2026").map { ymd($0.date).day }) == 20
                }
                it("'mar 20, 2026' resolves to year 2026") {
                    expect(parseDate("mar 20, 2026").map { ymd($0.date).year }) == 2026
                }
                it("'jan 5' resolves successfully") {
                    expect(parseDate("jan 5")).toNot(beNil())
                }
                it("'jan 5' resolves to month 1") {
                    expect(parseDate("jan 5").map { ymd($0.date).month }) == 1
                }
                it("'jan 5' resolves to day 5") {
                    expect(parseDate("jan 5").map { ymd($0.date).day }) == 5
                }
                it("'dec 31, 2027' resolves successfully") {
                    expect(parseDate("dec 31, 2027")).toNot(beNil())
                }
                it("'dec 31, 2027' resolves to month 12") {
                    expect(parseDate("dec 31, 2027").map { ymd($0.date).month }) == 12
                }
                it("'dec 31, 2027' resolves to year 2027") {
                    expect(parseDate("dec 31, 2027").map { ymd($0.date).year }) == 2027
                }
            }

            context("invalid input") {
                it("returns nil for unrecognized input") {
                    expect(parseDate("banana")).to(beNil())
                }
                it("returns nil for multi-word nonsense") {
                    expect(parseDate("foo bar baz")).to(beNil())
                }
            }
        }

        describe("formatDate") {
            let d = cal.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 14, minute: 30))!

            it("date-only format is non-empty") {
                expect(formatDate(d, showTime: false)).toNot(beEmpty())
            }
            it("date-only format does not contain the time") {
                expect(formatDate(d, showTime: false)).toNot(contain("2:30"))
            }
            it("date+time format is non-empty") {
                expect(formatDate(d, showTime: true)).toNot(beEmpty())
            }
            it("date+time format is longer than date-only") {
                expect(formatDate(d, showTime: true).count) > formatDate(d, showTime: false).count
            }
        }
    }
}
