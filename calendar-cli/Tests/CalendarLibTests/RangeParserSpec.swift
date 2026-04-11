// RangeParserSpec.swift
//
// Tests for GetClearKit RangeParser — date range string parsing into ParsedRange.

import Quick
import Nimble
import Foundation
import GetClearKit

final class RangeParserSpec: QuickSpec {
    override class func spec() {
        let cal = Calendar.current

        func sameDay(_ a: Date, _ b: Date) -> Bool {
            cal.isDate(a, inSameDayAs: b)
        }

        describe("parseRange") {
            context("single-day shorthands") {
                it("'today' resolves to today") {
                    expect(parseRange("today").map { sameDay($0.start, Date()) }) == true
                }
                it("'today' is a single-day range") {
                    expect(parseRange("today")?.isSingleDay) == true
                }
                it("'tomorrow' resolves to tomorrow") {
                    let expected = cal.date(byAdding: .day, value: 1, to: Date())!
                    expect(parseRange("tomorrow").map { sameDay($0.start, expected) }) == true
                }
                it("'tomorrow' is a single-day range") {
                    expect(parseRange("tomorrow")?.isSingleDay) == true
                }
                it("'yesterday' resolves to yesterday") {
                    let expected = cal.date(byAdding: .day, value: -1, to: Date())!
                    expect(parseRange("yesterday").map { sameDay($0.start, expected) }) == true
                }
                it("'yesterday' is a single-day range") {
                    expect(parseRange("yesterday")?.isSingleDay) == true
                }
            }

            context("weekday names") {
                let days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]

                it("each weekday resolves to a future or current date") {
                    for day in days {
                        expect(parseRange(day).map { $0.start >= cal.startOfDay(for: Date()) }) == true
                    }
                }
                it("each weekday is a single-day range") {
                    for day in days {
                        expect(parseRange(day)?.isSingleDay) == true
                    }
                }
                it("'next friday' resolves to the same date as 'friday'") {
                    expect(parseRange("next friday")?.start) == parseRange("friday")?.start
                }
            }

            context("specific dates — month and day") {
                it("'march 15' resolves to month 3") {
                    expect(parseRange("march 15").map { cal.component(.month, from: $0.start) }) == 3
                }
                it("'march 15' resolves to day 15") {
                    expect(parseRange("march 15").map { cal.component(.day, from: $0.start) }) == 15
                }
                it("'march 15' is a single-day range") {
                    expect(parseRange("march 15")?.isSingleDay) == true
                }
                it("past month+day rolls forward to the future") {
                    expect(parseRange("march 15").map { $0.start >= cal.startOfDay(for: Date()) }) == true
                }
            }

            context("specific dates — ISO") {
                it("'2026-03-15' resolves to year 2026") {
                    expect(parseRange("2026-03-15").map { cal.component(.year,  from: $0.start) }) == 2026
                }
                it("'2026-03-15' resolves to month 3") {
                    expect(parseRange("2026-03-15").map { cal.component(.month, from: $0.start) }) == 3
                }
                it("'2026-03-15' resolves to day 15") {
                    expect(parseRange("2026-03-15").map { cal.component(.day,   from: $0.start) }) == 15
                }
                it("'2026-03-15' is a single-day range") {
                    expect(parseRange("2026-03-15")?.isSingleDay) == true
                }
            }

            context("specific dates — short numeric") {
                it("'3/15' resolves to month 3") {
                    expect(parseRange("3/15").map { cal.component(.month, from: $0.start) }) == 3
                }
                it("'3/15' resolves to day 15") {
                    expect(parseRange("3/15").map { cal.component(.day,   from: $0.start) }) == 15
                }
                it("'3/15' is a single-day range") {
                    expect(parseRange("3/15")?.isSingleDay) == true
                }
            }

            context("week spans") {
                it("'week' is not a single-day range") {
                    expect(parseRange("week")?.isSingleDay) == false
                }
                it("'week' start is on or before today") {
                    expect(parseRange("week").map { $0.start <= Date() }) == true
                }
                it("'week' end is on or after today") {
                    expect(parseRange("week").map { $0.end >= Date() }) == true
                }
                it("'this week' equals 'week'") {
                    expect(parseRange("this week")?.start) == parseRange("week")?.start
                }
                it("'next week' starts after this week ends") {
                    guard let w = parseRange("week"), let nw = parseRange("next week") else { return }
                    expect(nw.start > w.end) == true
                }
                it("'last week' ends before this week starts") {
                    guard let w = parseRange("week"), let lw = parseRange("last week") else { return }
                    expect(lw.end < w.start) == true
                }
            }

            context("month spans") {
                it("'month' is not a single-day range") {
                    expect(parseRange("month")?.isSingleDay) == false
                }
                it("'month' starts on the 1st") {
                    expect(parseRange("month").map { cal.component(.day, from: $0.start) }) == 1
                }
                it("'this month' equals 'month'") {
                    expect(parseRange("this month")?.start) == parseRange("month")?.start
                }
                it("'next month' starts after this month ends") {
                    guard let m = parseRange("month"), let nm = parseRange("next month") else { return }
                    expect(nm.start > m.end) == true
                }
                it("'last month' ends before this month starts") {
                    guard let m = parseRange("month"), let lm = parseRange("last month") else { return }
                    expect(lm.end < m.start) == true
                }
            }

            context("N-day windows") {
                it("'7d' is not a single-day range") {
                    expect(parseRange("7d")?.isSingleDay) == false
                }
                it("'7d' starts today") {
                    expect(parseRange("7d").map { sameDay($0.start, Date()) }) == true
                }
                it("'7d' spans 7 calendar days") {
                    guard let r = parseRange("7d") else { return }
                    let days = cal.dateComponents([.day], from: r.start, to: r.end).day ?? 0
                    expect(days) == 6
                }
                it("'1d' is a single-day range") {
                    expect(parseRange("1d")?.isSingleDay) == true
                }
                it("'30d' is not a single-day range") {
                    expect(parseRange("30d")?.isSingleDay) == false
                }
            }

            context("explicit ranges") {
                it("'march 15 to march 20' is not a single-day range") {
                    expect(parseRange("march 15 to march 20")?.isSingleDay) == false
                }
                it("'march 15 to march 20' starts on day 15") {
                    expect(parseRange("march 15 to march 20").map { cal.component(.day, from: $0.start) }) == 15
                }
                it("'march 15 to march 20' ends on day 20") {
                    expect(parseRange("march 15 to march 20").map { cal.component(.day, from: $0.end) }) == 20
                }
                it("'today to friday' starts today") {
                    expect(parseRange("today to friday").map { sameDay($0.start, Date()) }) == true
                }
            }

            context("range boundary times") {
                it("single-day range starts at midnight") {
                    guard let r = parseRange("today") else { return }
                    let comps = cal.dateComponents([.hour, .minute, .second], from: r.start)
                    expect(comps.hour == 0 && comps.minute == 0 && comps.second == 0) == true
                }
                it("single-day range ends at 23:59:59") {
                    guard let r = parseRange("today") else { return }
                    let comps = cal.dateComponents([.hour, .minute, .second], from: r.end)
                    expect(comps.hour == 23 && comps.minute == 59 && comps.second == 59) == true
                }
            }

            context("invalid input") {
                it("returns nil for unrecognized input") {
                    expect(parseRange("banana")).to(beNil())
                }
                it("returns nil for empty string") {
                    expect(parseRange("")).to(beNil())
                }
            }
        }

        describe("parseSingleDate") {
            it("'today' resolves to today") {
                expect(parseSingleDate("today", cal: cal, now: Date()).map { sameDay($0, Date()) }) == true
            }
            it("'tomorrow' resolves to tomorrow") {
                let expected = cal.date(byAdding: .day, value: 1, to: Date())!
                expect(parseSingleDate("tomorrow", cal: cal, now: Date()).map { sameDay($0, expected) }) == true
            }
            it("'friday' resolves to a date") {
                expect(parseSingleDate("friday", cal: cal, now: Date())).toNot(beNil())
            }
            it("'march 15' resolves to a date") {
                expect(parseSingleDate("march 15", cal: cal, now: Date())).toNot(beNil())
            }
            it("returns nil for unrecognized input") {
                expect(parseSingleDate("banana", cal: cal, now: Date())).to(beNil())
            }
        }
    }
}
