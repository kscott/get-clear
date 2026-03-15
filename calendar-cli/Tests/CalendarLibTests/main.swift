// main.swift — test runner for CalendarLib
//
// Does not require Xcode or XCTest — runs with just the Swift CLI toolchain.
// Run via:  calendar test

import Foundation
import CalendarLib
import GetClearKit

// MARK: - Minimal test harness

final class TestRunner: @unchecked Sendable {
    private var passed = 0
    private var failed = 0

    func expect(_ description: String, _ condition: Bool, file: String = #file, line: Int = #line) {
        if condition {
            print("  ✓ \(description)")
            passed += 1
        } else {
            print("  ✗ \(description)  [\(URL(fileURLWithPath: file).lastPathComponent):\(line)]")
            failed += 1
        }
    }

    func suite(_ name: String, _ body: () -> Void) {
        print("\n\(name)")
        body()
    }

    func run() {
        let cal = Calendar.current
        let now = Date()

        func ymd(_ date: Date) -> DateComponents {
            cal.dateComponents([.year, .month, .day], from: date)
        }
        func sameDay(_ a: Date, _ b: Date) -> Bool {
            cal.isDate(a, inSameDayAs: b)
        }

        // MARK: Single-day shorthands

        suite("Single-day shorthands") {
            let today = parseRange("today")
            expect("today — not nil",       today != nil)
            expect("today — isSingleDay",   today?.isSingleDay == true)
            expect("today — start is today", today.map { sameDay($0.start, now) } == true)
            expect("today — end is today",   today.map { sameDay($0.end,   now) } == true)

            let tomorrow = parseRange("tomorrow")
            let expectedTomorrow = cal.date(byAdding: .day, value: 1, to: now)!
            expect("tomorrow — not nil",      tomorrow != nil)
            expect("tomorrow — isSingleDay",  tomorrow?.isSingleDay == true)
            expect("tomorrow — correct day",  tomorrow.map { sameDay($0.start, expectedTomorrow) } == true)

            let yesterday = parseRange("yesterday")
            let expectedYesterday = cal.date(byAdding: .day, value: -1, to: now)!
            expect("yesterday — not nil",      yesterday != nil)
            expect("yesterday — isSingleDay",  yesterday?.isSingleDay == true)
            expect("yesterday — correct day",  yesterday.map { sameDay($0.start, expectedYesterday) } == true)
        }

        // MARK: Weekday names

        suite("Weekday names") {
            let days = ["monday","tuesday","wednesday","thursday","friday","saturday","sunday"]
            for day in days {
                let r = parseRange(day)
                expect("\(day) — not nil",      r != nil)
                expect("\(day) — isSingleDay",  r?.isSingleDay == true)
                expect("\(day) — not in past",  r.map { $0.start >= cal.startOfDay(for: now) } == true)
            }
            let friday     = parseRange("friday")
            let nextFriday = parseRange("next friday")
            expect("next friday == friday", friday?.start == nextFriday?.start)
        }

        // MARK: Specific dates

        suite("Specific dates — month + day") {
            let r = parseRange("march 15")
            expect("march 15 — not nil",   r != nil)
            expect("march 15 — month 3",   r.map { cal.component(.month, from: $0.start) } == 3)
            expect("march 15 — day 15",    r.map { cal.component(.day,   from: $0.start) } == 15)
            expect("march 15 — not in past", r.map { $0.start >= cal.startOfDay(for: now) } == true)
        }

        suite("Specific dates — ISO") {
            let r = parseRange("2026-03-15")
            expect("2026-03-15 — not nil",  r != nil)
            expect("2026-03-15 — year",     r.map { cal.component(.year,  from: $0.start) } == 2026)
            expect("2026-03-15 — month",    r.map { cal.component(.month, from: $0.start) } == 3)
            expect("2026-03-15 — day",      r.map { cal.component(.day,   from: $0.start) } == 15)
        }

        suite("Specific dates — short numeric") {
            let r = parseRange("3/15")
            expect("3/15 — not nil",  r != nil)
            expect("3/15 — month 3",  r.map { cal.component(.month, from: $0.start) } == 3)
            expect("3/15 — day 15",   r.map { cal.component(.day,   from: $0.start) } == 15)
        }

        // MARK: Week spans

        suite("Week spans") {
            let week = parseRange("week")
            expect("week — not nil",       week != nil)
            expect("week — not singleDay", week?.isSingleDay == false)
            expect("week — start <= today", week.map { $0.start <= now } == true)
            expect("week — end >= today",   week.map { $0.end   >= now } == true)

            let nextWeek = parseRange("next week")
            expect("next week — not nil",        nextWeek != nil)
            expect("next week — starts after this week", {
                guard let w = week, let nw = nextWeek else { return false }
                return nw.start > w.end
            }())

            let lastWeek = parseRange("last week")
            expect("last week — not nil",       lastWeek != nil)
            expect("last week — ends before this week", {
                guard let w = week, let lw = lastWeek else { return false }
                return lw.end < w.start
            }())

            let thisWeek = parseRange("this week")
            expect("this week == week", week?.start == thisWeek?.start && week?.end == thisWeek?.end)
        }

        // MARK: Month spans

        suite("Month spans") {
            let month = parseRange("month")
            expect("month — not nil",       month != nil)
            expect("month — not singleDay", month?.isSingleDay == false)
            expect("month — start is 1st",  month.map { cal.component(.day, from: $0.start) } == 1)

            let nextMonth = parseRange("next month")
            expect("next month — not nil",          nextMonth != nil)
            expect("next month — after this month", {
                guard let m = month, let nm = nextMonth else { return false }
                return nm.start > m.end
            }())

            let lastMonth = parseRange("last month")
            expect("last month — not nil",           lastMonth != nil)
            expect("last month — before this month", {
                guard let m = month, let lm = lastMonth else { return false }
                return lm.end < m.start
            }())
        }

        // MARK: N-day windows

        suite("N-day windows") {
            let d7 = parseRange("7d")
            expect("7d — not nil",       d7 != nil)
            expect("7d — not singleDay", d7?.isSingleDay == false)
            expect("7d — start is today", d7.map { sameDay($0.start, now) } == true)
            expect("7d — spans 7 days", {
                guard let r = d7 else { return false }
                let days = cal.dateComponents([.day], from: r.start, to: r.end).day ?? 0
                return days == 6 // startOfDay to endOfDay is 6 days apart (not 7)
            }())

            let d1 = parseRange("1d")
            expect("1d — isSingleDay",   d1?.isSingleDay == true)

            let d30 = parseRange("30d")
            expect("30d — not nil",      d30 != nil)
            expect("30d — not singleDay", d30?.isSingleDay == false)
        }

        // MARK: Explicit ranges

        suite("Explicit ranges") {
            let r = parseRange("march 15 to march 20")
            expect("march 15 to march 20 — not nil",   r != nil)
            expect("march 15 to march 20 — not single", r?.isSingleDay == false)
            expect("march 15 to march 20 — start month", r.map { cal.component(.month, from: $0.start) } == 3)
            expect("march 15 to march 20 — start day 15", r.map { cal.component(.day, from: $0.start) } == 15)
            expect("march 15 to march 20 — end day 20",   r.map { cal.component(.day, from: $0.end)   } == 20)

            let r2 = parseRange("today to friday")
            expect("today to friday — not nil",    r2 != nil)
            expect("today to friday — start today", r2.map { sameDay($0.start, now) } == true)
        }

        // MARK: Invalid input

        suite("Invalid input") {
            expect("garbage returns nil",    parseRange("not a range") == nil)
            expect("empty string returns nil", parseRange("") == nil)
            expect("banana returns nil",     parseRange("banana") == nil)
        }

        // MARK: ConfigParser

        suite("ConfigParser — empty/missing config") {
            let c = parseConfig("")
            expect("empty content — no subsets", c.subsets.isEmpty)
        }

        suite("ConfigParser — basic subsets") {
            let toml = """
            [subsets]
            work     = ["Work", "Meetings"]
            personal = ["Home", "Family", "Birthdays & Anniversaries"]
            """
            let c = parseConfig(toml)
            expect("work subset exists",       c.subsets["work"] != nil)
            expect("work has 2 calendars",     c.subsets["work"]?.count == 2)
            expect("work includes Work",       c.subsets["work"]?.contains("Work") == true)
            expect("work includes Meetings",   c.subsets["work"]?.contains("Meetings") == true)
            expect("personal has 3 calendars", c.subsets["personal"]?.count == 3)
            expect("personal includes Birthdays & Anniversaries",
                   c.subsets["personal"]?.contains("Birthdays & Anniversaries") == true)
        }

        suite("ConfigParser — subset names are lowercased") {
            let toml = """
            [subsets]
            Work = ["Work"]
            """
            let c = parseConfig(toml)
            expect("key is lowercased", c.subsets["work"] != nil)
            expect("original case not stored", c.subsets["Work"] == nil)
        }

        suite("ConfigParser — ignores non-subsets sections") {
            let toml = """
            [other]
            foo = ["bar"]

            [subsets]
            personal = ["Home"]
            """
            let c = parseConfig(toml)
            expect("only personal parsed", c.subsets.count == 1)
            expect("personal exists",      c.subsets["personal"] != nil)
            expect("foo not parsed",       c.subsets["foo"] == nil)
        }

        suite("ConfigParser — ignores comments and blank lines") {
            let toml = """
            # This is a comment

            [subsets]
            # another comment
            work = ["Work"]
            """
            let c = parseConfig(toml)
            expect("work parsed despite comments", c.subsets["work"] != nil)
        }

        print("\n\(passed + failed) tests: \(passed) passed, \(failed) failed")
        if failed > 0 { exit(1) }
    }
}

TestRunner().run()
