// main.swift — test runner for GetClearKit
//
// Does not require Xcode or XCTest — runs with just the Swift CLI toolchain.
// Run via:  swift run getclearkit-tests  (from get-clear repo root)

import Foundation
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
        func hm(_ date: Date) -> DateComponents {
            cal.dateComponents([.hour, .minute], from: date)
        }
        func sameDay(_ a: Date, _ b: Date) -> Bool {
            cal.isDate(a, inSameDayAs: b)
        }

        // MARK: - DateParser: hasTime / hasDate flags

        suite("hasTime flag") {
            expect("date only — hasTime false",      parseDate("tomorrow")?.hasTime      == false)
            expect("weekday only — hasTime false",   parseDate("friday")?.hasTime        == false)
            expect("month+day only — hasTime false", parseDate("march 15")?.hasTime      == false)
            expect("time included — hasTime true",   parseDate("3pm")?.hasTime           == true)
            expect("tomorrow 3pm — hasTime true",    parseDate("tomorrow 3pm")?.hasTime  == true)
            expect("friday at 5pm — hasTime true",   parseDate("friday at 5pm")?.hasTime == true)
            expect("14:30 — hasTime true",           parseDate("14:30")?.hasTime         == true)
        }

        suite("hasDate flag") {
            expect("time only (3pm) — hasDate false",   parseDate("3pm")?.hasDate          == false)
            expect("time only (8:30pm) — hasDate false", parseDate("8:30pm")?.hasDate      == false)
            expect("time only (14:30) — hasDate false", parseDate("14:30")?.hasDate        == false)
            expect("tomorrow — hasDate true",           parseDate("tomorrow")?.hasDate     == true)
            expect("friday — hasDate true",             parseDate("friday")?.hasDate       == true)
            expect("march 15 — hasDate true",           parseDate("march 15")?.hasDate     == true)
            expect("ISO date — hasDate true",           parseDate("2026-03-15")?.hasDate   == true)
            expect("friday at 5pm — hasDate true",      parseDate("friday at 5pm")?.hasDate == true)
            expect("tomorrow 3pm — hasDate true",       parseDate("tomorrow 3pm")?.hasDate == true)
        }

        // MARK: - DateParser: relative days

        suite("Relative days") {
            expect("today matches current date", ymd(parseDate("today")!.date) == ymd(now))
            let tomorrow = ymd(cal.date(byAdding: .day, value: 1, to: now)!)
            expect("tomorrow is tomorrow", ymd(parseDate("tomorrow")!.date) == tomorrow)
        }

        // MARK: - DateParser: weekdays

        suite("Weekdays") {
            let days = ["monday","tuesday","wednesday","thursday","friday","saturday","sunday"]
            for day in days {
                let pd = parseDate(day)!
                expect("\(day) is in the future", pd.date > now)
                let dayDiff = cal.dateComponents([.day],
                    from: cal.startOfDay(for: now),
                    to:   cal.startOfDay(for: pd.date)).day!
                expect("\(day) is within 7 days", dayDiff <= 7)
            }
        }

        suite("next/this prefix — parseDate") {
            let friday     = parseDate("friday")!.date
            let nextFriday = parseDate("next friday")!.date
            let thisFriday = parseDate("this friday")!.date
            expect("next friday == friday", nextFriday == friday)
            expect("this friday == friday", thisFriday == friday)

            let monday     = parseDate("monday")!.date
            let nextMonday = parseDate("next monday")!.date
            expect("next monday == monday", nextMonday == monday)
        }

        // MARK: - DateParser: month + day

        suite("Month + day") {
            let pd = parseDate("march 15")!
            expect("march 15 — correct month", ymd(pd.date).month == 3)
            expect("march 15 — correct day",   ymd(pd.date).day   == 15)
            let jan1 = parseDate("january 1")!
            expect("january 1 rolls to future if past", jan1.date >= now)
        }

        suite("Month + day + year") {
            let a = parseDate("march 10 2027")!
            expect("march 10 2027 — year",  ymd(a.date).year  == 2027)
            expect("march 10 2027 — month", ymd(a.date).month == 3)
            expect("march 10 2027 — day",   ymd(a.date).day   == 10)

            let b = parseDate("march 10, 2027")!
            expect("march 10, 2027 — year",  ymd(b.date).year  == 2027)
            expect("march 10, 2027 — month", ymd(b.date).month == 3)
            expect("march 10, 2027 — day",   ymd(b.date).day   == 10)

            let c = parseDate("10 march 2027")!
            expect("10 march 2027 — year",  ymd(c.date).year  == 2027)
            expect("10 march 2027 — month", ymd(c.date).month == 3)
            expect("10 march 2027 — day",   ymd(c.date).day   == 10)

            let d = parseDate("january 1 28")!
            expect("january 1 28 — 2-digit year expands to 2028", ymd(d.date).year == 2028)
        }

        // MARK: - DateParser: numeric formats

        suite("Numeric dates") {
            let iso = parseDate("2026-03-15")!
            expect("ISO year",  ymd(iso.date).year  == 2026)
            expect("ISO month", ymd(iso.date).month == 3)
            expect("ISO day",   ymd(iso.date).day   == 15)

            let slash = parseDate("3/15")!
            expect("3/15 month", ymd(slash.date).month == 3)
            expect("3/15 day",   ymd(slash.date).day   == 15)

            let dash = parseDate("3-15")!
            expect("3-15 month", ymd(dash.date).month == 3)
            expect("3-15 day",   ymd(dash.date).day   == 15)

            expect("1/1 rolls to future if past", parseDate("1/1")!.date >= now)

            let usLong = parseDate("3/10/2027")!
            expect("3/10/2027 — US M/D/Y — year",  ymd(usLong.date).year  == 2027)
            expect("3/10/2027 — US M/D/Y — month", ymd(usLong.date).month == 3)
            expect("3/10/2027 — US M/D/Y — day",   ymd(usLong.date).day   == 10)

            let usShort = parseDate("3/10/27")!
            expect("3/10/27 — 2-digit year — year",  ymd(usShort.date).year  == 2027)
            expect("3/10/27 — 2-digit year — month", ymd(usShort.date).month == 3)
            expect("3/10/27 — 2-digit year — day",   ymd(usShort.date).day   == 10)
        }

        // MARK: - DateParser: time parsing

        suite("Time parsing") {
            expect("3pm is hour 15",   hm(parseDate("3pm")!.date).hour   == 15)
            expect("10am is hour 10",  hm(parseDate("10am")!.date).hour  == 10)
            expect("12pm is noon",     hm(parseDate("12pm")!.date).hour  == 12)
            expect("12am is midnight", hm(parseDate("12am")!.date).hour  == 0)
            expect("14:30 hour",       hm(parseDate("14:30")!.date).hour   == 14)
            expect("14:30 minute",     hm(parseDate("14:30")!.date).minute == 30)
            expect("2:45pm hour",      hm(parseDate("2:45pm")!.date).hour   == 14)
            expect("2:45pm minute",    hm(parseDate("2:45pm")!.date).minute == 45)
            expect("8:30pm hour",      hm(parseDate("8:30pm")!.date).hour   == 20)
            expect("8:30pm minute",    hm(parseDate("8:30pm")!.date).minute == 30)
        }

        suite("Combined day + time") {
            let t1 = parseDate("tomorrow 3pm")!
            let tomorrowYMD = ymd(cal.date(byAdding: .day, value: 1, to: now)!)
            expect("tomorrow 3pm — correct day",  ymd(t1.date) == tomorrowYMD)
            expect("tomorrow 3pm — correct time", hm(t1.date).hour == 15)

            let t2 = parseDate("friday at 5pm")!
            expect("friday at 5pm — in the future", t2.date > now)
            expect("friday at 5pm — correct time",  hm(t2.date).hour == 17)

            let t3 = parseDate("march 15 9am")!
            expect("march 15 9am — month", ymd(t3.date).month == 3)
            expect("march 15 9am — day",   ymd(t3.date).day   == 15)
            expect("march 15 9am — hour",  hm(t3.date).hour   == 9)

            let t4 = parseDate("monday at 8am")!
            expect("monday at 8am — hasDate", t4.hasDate == true)
            expect("monday at 8am — hasTime", t4.hasTime == true)
            expect("monday at 8am — hour",    hm(t4.date).hour == 8)
        }

        // MARK: - DateParser: invalid input

        suite("Invalid input — parseDate") {
            expect("garbage returns nil",  parseDate("not a date") == nil)
            expect("nonsense returns nil", parseDate("banana")     == nil)
            expect("3-part nonsense nil",  parseDate("foo bar baz") == nil)
        }

        suite("Abbreviated month names — parseDate") {
            // Regression: "Mar 20, 2026" was not recognised (reminders-cli #16)
            let mar20 = parseDate("mar 20, 2026")
            expect("mar 20, 2026 — not nil",  mar20 != nil)
            expect("mar 20, 2026 — month 3",  mar20.map { cal.component(.month, from: $0.date) } == 3)
            expect("mar 20, 2026 — day 20",   mar20.map { cal.component(.day,   from: $0.date) } == 20)
            expect("mar 20, 2026 — year 2026",mar20.map { cal.component(.year,  from: $0.date) } == 2026)

            let jan5 = parseDate("jan 5")
            expect("jan 5 — not nil",   jan5 != nil)
            expect("jan 5 — month 1",   jan5.map { cal.component(.month, from: $0.date) } == 1)
            expect("jan 5 — day 5",     jan5.map { cal.component(.day,   from: $0.date) } == 5)

            let dec31 = parseDate("dec 31, 2027")
            expect("dec 31, 2027 — not nil",   dec31 != nil)
            expect("dec 31, 2027 — month 12",  dec31.map { cal.component(.month, from: $0.date) } == 12)
            expect("dec 31, 2027 — year 2027", dec31.map { cal.component(.year,  from: $0.date) } == 2027)
        }

        // MARK: - RangeParser: single-day shorthands

        suite("Single-day shorthands") {
            let today = parseRange("today")
            expect("today — not nil",        today != nil)
            expect("today — isSingleDay",    today?.isSingleDay == true)
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

        // MARK: - RangeParser: weekday names

        suite("Weekday names — parseRange") {
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

        // MARK: - RangeParser: specific dates

        suite("Specific dates — month + day") {
            let r = parseRange("march 15")
            expect("march 15 — not nil",       r != nil)
            expect("march 15 — month 3",       r.map { cal.component(.month, from: $0.start) } == 3)
            expect("march 15 — day 15",        r.map { cal.component(.day,   from: $0.start) } == 15)
            expect("march 15 — not in past",   r.map { $0.start >= cal.startOfDay(for: now) } == true)
            expect("march 15 — isSingleDay",   r?.isSingleDay == true)
        }

        suite("Specific dates — ISO") {
            let r = parseRange("2026-03-15")
            expect("2026-03-15 — not nil",  r != nil)
            expect("2026-03-15 — year",     r.map { cal.component(.year,  from: $0.start) } == 2026)
            expect("2026-03-15 — month",    r.map { cal.component(.month, from: $0.start) } == 3)
            expect("2026-03-15 — day",      r.map { cal.component(.day,   from: $0.start) } == 15)
            expect("2026-03-15 — isSingleDay", r?.isSingleDay == true)
        }

        suite("Specific dates — short numeric") {
            let r = parseRange("3/15")
            expect("3/15 — not nil",    r != nil)
            expect("3/15 — month 3",    r.map { cal.component(.month, from: $0.start) } == 3)
            expect("3/15 — day 15",     r.map { cal.component(.day,   from: $0.start) } == 15)
            expect("3/15 — isSingleDay", r?.isSingleDay == true)
        }

        // MARK: - RangeParser: week spans

        suite("Week spans") {
            let week = parseRange("week")
            expect("week — not nil",        week != nil)
            expect("week — not singleDay",  week?.isSingleDay == false)
            expect("week — start <= today", week.map { $0.start <= now } == true)
            expect("week — end >= today",   week.map { $0.end   >= now } == true)

            let thisWeek = parseRange("this week")
            expect("this week == week",
                   week?.start == thisWeek?.start && week?.end == thisWeek?.end)

            let nextWeek = parseRange("next week")
            expect("next week — not nil", nextWeek != nil)
            expect("next week — starts after this week", {
                guard let w = week, let nw = nextWeek else { return false }
                return nw.start > w.end
            }())

            let lastWeek = parseRange("last week")
            expect("last week — not nil", lastWeek != nil)
            expect("last week — ends before this week", {
                guard let w = week, let lw = lastWeek else { return false }
                return lw.end < w.start
            }())
        }

        // MARK: - RangeParser: month spans

        suite("Month spans") {
            let month = parseRange("month")
            expect("month — not nil",       month != nil)
            expect("month — not singleDay", month?.isSingleDay == false)
            expect("month — start is 1st",  month.map { cal.component(.day, from: $0.start) } == 1)

            let thisMonth = parseRange("this month")
            expect("this month == month",
                   month?.start == thisMonth?.start && month?.end == thisMonth?.end)

            let nextMonth = parseRange("next month")
            expect("next month — not nil", nextMonth != nil)
            expect("next month — after this month", {
                guard let m = month, let nm = nextMonth else { return false }
                return nm.start > m.end
            }())

            let lastMonth = parseRange("last month")
            expect("last month — not nil", lastMonth != nil)
            expect("last month — before this month", {
                guard let m = month, let lm = lastMonth else { return false }
                return lm.end < m.start
            }())
        }

        // MARK: - RangeParser: N-day windows

        suite("N-day windows") {
            let d7 = parseRange("7d")
            expect("7d — not nil",        d7 != nil)
            expect("7d — not singleDay",  d7?.isSingleDay == false)
            expect("7d — start is today", d7.map { sameDay($0.start, now) } == true)
            expect("7d — spans 7 calendar days", {
                guard let r = d7 else { return false }
                let days = cal.dateComponents([.day], from: r.start, to: r.end).day ?? 0
                return days == 6  // startOfDay to endOfDay is 6 days (not 7)
            }())

            let d1 = parseRange("1d")
            expect("1d — isSingleDay", d1?.isSingleDay == true)

            let d30 = parseRange("30d")
            expect("30d — not nil",       d30 != nil)
            expect("30d — not singleDay", d30?.isSingleDay == false)
        }

        // MARK: - RangeParser: explicit ranges

        suite("Explicit ranges") {
            let r = parseRange("march 15 to march 20")
            expect("march 15 to march 20 — not nil",    r != nil)
            expect("march 15 to march 20 — not single", r?.isSingleDay == false)
            expect("march 15 to march 20 — start month",
                   r.map { cal.component(.month, from: $0.start) } == 3)
            expect("march 15 to march 20 — start day 15",
                   r.map { cal.component(.day, from: $0.start) } == 15)
            expect("march 15 to march 20 — end day 20",
                   r.map { cal.component(.day, from: $0.end) } == 20)

            let r2 = parseRange("today to friday")
            expect("today to friday — not nil",     r2 != nil)
            expect("today to friday — start today", r2.map { sameDay($0.start, now) } == true)

            let r3 = parseRange("yesterday to tomorrow")
            expect("yesterday to tomorrow — not nil",   r3 != nil)
            expect("yesterday to tomorrow — not single", r3?.isSingleDay == false)
        }

        // MARK: - RangeParser: parseSingleDate directly

        suite("parseSingleDate") {
            let c = Calendar.current
            let n = Date()
            expect("today", parseSingleDate("today",     cal: c, now: n).map { sameDay($0, n) } == true)
            expect("tomorrow", parseSingleDate("tomorrow", cal: c, now: n).map {
                sameDay($0, c.date(byAdding: .day, value: 1, to: n)!) } == true)
            expect("yesterday", parseSingleDate("yesterday", cal: c, now: n).map {
                sameDay($0, c.date(byAdding: .day, value: -1, to: n)!) } == true)
            expect("friday — not nil",   parseSingleDate("friday",     cal: c, now: n) != nil)
            expect("march 15 — not nil", parseSingleDate("march 15",   cal: c, now: n) != nil)
            expect("2026-03-15 — not nil", parseSingleDate("2026-03-15", cal: c, now: n) != nil)
            expect("3/15 — not nil",     parseSingleDate("3/15",       cal: c, now: n) != nil)
            expect("banana — nil",       parseSingleDate("banana",     cal: c, now: n) == nil)
        }

        // MARK: - RangeParser: invalid input

        suite("Invalid input — parseRange") {
            expect("garbage returns nil",      parseRange("not a range") == nil)
            expect("empty string returns nil", parseRange("")            == nil)
            expect("banana returns nil",       parseRange("banana")      == nil)
        }

        // MARK: - RangeParser: boundary behaviour

        suite("Range boundary times") {
            // Start of a single-day range should be start of day (00:00)
            let r = parseRange("today")!
            let startComps = cal.dateComponents([.hour, .minute, .second], from: r.start)
            expect("single day start is midnight",
                   startComps.hour == 0 && startComps.minute == 0 && startComps.second == 0)
            // End of a single-day range should be 23:59:59
            let endComps = cal.dateComponents([.hour, .minute, .second], from: r.end)
            expect("single day end is 23:59:59",
                   endComps.hour == 23 && endComps.minute == 59 && endComps.second == 59)
        }

        // MARK: - formatDate

        suite("formatDate") {
            let d = cal.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 14, minute: 30))!
            let dateOnly = formatDate(d, showTime: false)
            expect("date-only format is non-empty", !dateOnly.isEmpty)
            expect("date-only does not contain time", !dateOnly.contains("2:30"))

            let withTime = formatDate(d, showTime: true)
            expect("date+time format is non-empty", !withTime.isEmpty)
            // Time component should appear somewhere
            expect("date+time contains time info", withTime.count > dateOnly.count)
        }

        // MARK: - formatRangeDescription

        suite("formatRangeDescription") {
            let singleDayRange = parseRange("today")!
            let desc = formatRangeDescription(singleDayRange)
            expect("single day description is non-empty", !desc.isEmpty)
            // Should include day name for single-day
            let dayNames = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
            expect("single day description includes weekday name",
                   dayNames.contains(where: { desc.contains($0) }))

            let multiDayRange = parseRange("week")!
            let multiDesc = formatRangeDescription(multiDayRange)
            expect("multi-day description is non-empty", !multiDesc.isEmpty)
            expect("multi-day description includes em-dash", multiDesc.contains("–"))
        }

        // MARK: - ActivityLog

        suite("ActivityLog write — file creation") {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("gc-test-\(UUID().uuidString)")
            try? ActivityLog.write(tool: "reminders", cmd: "done", desc: "Call Sarah",
                                   container: "Ibotta", baseDirectory: tempDir)
            let today = ISO8601DateFormatter.logFileDateString(Date())
            let file = tempDir.appendingPathComponent("\(today).log")
            expect("log directory is created", FileManager.default.fileExists(atPath: tempDir.path))
            expect("log file is created", FileManager.default.fileExists(atPath: file.path))
        }

        suite("ActivityLog write — entry content") {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("gc-test-\(UUID().uuidString)")
            try? ActivityLog.write(tool: "reminders", cmd: "done", desc: "Call Sarah",
                                   container: "Ibotta", baseDirectory: tempDir)
            let today = ISO8601DateFormatter.logFileDateString(Date())
            let file = tempDir.appendingPathComponent("\(today).log")
            let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
            expect("exactly one line written", lines.count == 1)
            let data = Data(lines[0].utf8)
            let entry = try? JSONDecoder.logDecoder().decode(ActivityLogEntry.self, from: data)
            expect("entry parses as ActivityLogEntry", entry != nil)
            expect("tool is correct",      entry?.tool      == "reminders")
            expect("cmd is correct",       entry?.cmd       == "done")
            expect("desc is correct",      entry?.desc      == "Call Sarah")
            expect("container is correct", entry?.container == "Ibotta")
            expect("ts is recent",         entry.map { abs($0.ts.timeIntervalSinceNow) < 5 } == true)
        }

        suite("ActivityLog write — nil container") {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("gc-test-\(UUID().uuidString)")
            try? ActivityLog.write(tool: "mail", cmd: "send", desc: "Alex Re: notes",
                                   container: nil, baseDirectory: tempDir)
            let today = ISO8601DateFormatter.logFileDateString(Date())
            let file = tempDir.appendingPathComponent("\(today).log")
            let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            expect("nil container serializes as null", content.contains("\"container\":null"))
            let data = Data(content.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
            let entry = try? JSONDecoder.logDecoder().decode(ActivityLogEntry.self, from: data)
            expect("container field is nil after round-trip", entry?.container == nil)
        }

        suite("ActivityLog write — appends, does not overwrite") {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("gc-test-\(UUID().uuidString)")
            try? ActivityLog.write(tool: "reminders", cmd: "add",  desc: "First",  container: nil, baseDirectory: tempDir)
            try? ActivityLog.write(tool: "reminders", cmd: "done", desc: "Second", container: nil, baseDirectory: tempDir)
            let today = ISO8601DateFormatter.logFileDateString(Date())
            let file = tempDir.appendingPathComponent("\(today).log")
            let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
            expect("both entries present", lines.count == 2)
            expect("first entry is first",  lines[0].contains("\"First\""))
            expect("second entry is second", lines[1].contains("\"Second\""))
        }

        // MARK: - ActivityLogReader

        suite("ActivityLogReader — basic parse and filter") {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("gc-test-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let today = ISO8601DateFormatter.logFileDateString(Date())
            let file = tempDir.appendingPathComponent("\(today).log")
            // Use startOfDay + fixed offsets so timestamps are always within today's range,
            // regardless of when the test runs or what timezone the runner is in.
            let dayStart = cal.startOfDay(for: Date())
            let fmt = ISO8601DateFormatter()
            let ts1 = fmt.string(from: dayStart.addingTimeInterval(8 * 3600))
            let ts2 = fmt.string(from: dayStart.addingTimeInterval(9 * 3600))
            let ts3 = fmt.string(from: dayStart.addingTimeInterval(10 * 3600))
            let lines = [
                #"{"ts":"\#(ts1)","tool":"reminders","cmd":"done","desc":"Call Sarah","container":"Ibotta"}"#,
                #"{"ts":"\#(ts2)","tool":"mail","cmd":"send","desc":"Alex Re: notes","container":null}"#,
                #"{"ts":"\#(ts3)","tool":"reminders","cmd":"add","desc":"Review PR","container":"Ibotta"}"#,
            ].joined(separator: "\n") + "\n"
            try? lines.write(to: file, atomically: true, encoding: .utf8)
            let range = parseRange("today")!
            let all = ActivityLogReader.entries(in: range.start...range.end, tool: nil, baseDirectory: tempDir)
            expect("reads all 3 entries",      all.count == 3)
            let remOnly = ActivityLogReader.entries(in: range.start...range.end, tool: "reminders", baseDirectory: tempDir)
            expect("filters to 2 reminders entries", remOnly.count == 2)
            let mailOnly = ActivityLogReader.entries(in: range.start...range.end, tool: "mail", baseDirectory: tempDir)
            expect("filters to 1 mail entry",  mailOnly.count == 1)
        }

        suite("ActivityLogReader — skips malformed lines") {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("gc-test-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let today = ISO8601DateFormatter.logFileDateString(Date())
            let file = tempDir.appendingPathComponent("\(today).log")
            let dayStart = cal.startOfDay(for: Date())
            let fmt = ISO8601DateFormatter()
            let tsGood = fmt.string(from: dayStart.addingTimeInterval(8 * 3600))
            let tsBad1 = fmt.string(from: dayStart.addingTimeInterval(9 * 3600))
            let tsBad2 = fmt.string(from: dayStart.addingTimeInterval(10 * 3600))
            let lines = [
                #"not json at all"#,
                #"{"ts":"\#(tsGood)","tool":"reminders","cmd":"done","desc":"Good entry","container":null}"#,
                #"{"ts":"broken-date","tool":"reminders","cmd":"done","desc":"Bad ts","container":null}"#,
                #"{"ts":"\#(tsBad1)","tool":"unknown-tool","cmd":"done","desc":"Unknown tool","container":null}"#,
                #"{"ts":"\#(tsBad2)","tool":"reminders","cmd":"done","desc":"","container":null}"#,
            ].joined(separator: "\n") + "\n"
            try? lines.write(to: file, atomically: true, encoding: .utf8)
            let range = parseRange("today")!
            let entries = ActivityLogReader.entries(in: range.start...range.end, tool: nil, baseDirectory: tempDir)
            expect("only 1 valid entry survives", entries.count == 1)
            expect("surviving entry is the good one", entries.first?.desc == "Good entry")
        }

        suite("ActivityLogReader — FR-018 recency rule") {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("gc-test-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Write an entry timestamped 2 hours ago into yesterday's file
            let recentNow = Date()
            let twoHoursAgo = recentNow.addingTimeInterval(-2 * 3600)
            let yesterdayStr = ISO8601DateFormatter.logFileDateString(
                cal.date(byAdding: .day, value: -1, to: recentNow)!)
            let file = tempDir.appendingPathComponent("\(yesterdayStr).log")
            let formatter = ISO8601DateFormatter()
            let tsStr = formatter.string(from: twoHoursAgo)
            let line = #"{"ts":"\#(tsStr)","tool":"reminders","cmd":"done","desc":"Late night task","container":null}"# + "\n"
            try? line.write(to: file, atomically: true, encoding: .utf8)

            // Today's file is empty — FR-018 should kick in (within 3 hours)
            let todayRange = parseRange("today")!
            let result = ActivityLogReader.entriesForDisplay(
                in: todayRange.start...todayRange.end,
                now: recentNow,
                baseDirectory: tempDir)
            expect("FR-018: shows yesterday's entry when within 3 hours", result.entries.count == 1)
            expect("FR-018: reported date is yesterday, not today",
                   !cal.isDateInToday(result.dateUsed))

            // Entry more than 3 hours ago — FR-018 should NOT trigger
            let fourHoursAgo = recentNow.addingTimeInterval(-4 * 3600)
            let tsStr2 = formatter.string(from: fourHoursAgo)
            let line2 = #"{"ts":"\#(tsStr2)","tool":"reminders","cmd":"done","desc":"Old task","container":null}"# + "\n"
            let tempDir2 = FileManager.default.temporaryDirectory
                .appendingPathComponent("gc-test-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir2, withIntermediateDirectories: true)
            let file2 = tempDir2.appendingPathComponent("\(yesterdayStr).log")
            try? line2.write(to: file2, atomically: true, encoding: .utf8)
            let result2 = ActivityLogReader.entriesForDisplay(
                in: todayRange.start...todayRange.end,
                now: recentNow,
                baseDirectory: tempDir2)
            expect("FR-018: does not trigger when last entry > 3 hours ago", result2.entries.isEmpty)
        }

        // MARK: - TimespanFormatter

        suite("TimespanFormatter — 15-minute rounding") {
            func makeDate(hour: Int, minute: Int) -> Date {
                cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
            }
            func roundedMinute(_ h: Int, _ m: Int) -> Int {
                cal.component(.minute, from: TimespanFormatter.roundTo15Minutes(makeDate(hour: h, minute: m)))
            }
            func roundedHour(_ h: Int, _ m: Int) -> Int {
                cal.component(.hour, from: TimespanFormatter.roundTo15Minutes(makeDate(hour: h, minute: m)))
            }

            expect("X:07 rounds down to X:00", roundedMinute(9, 7)  == 0)
            expect("X:08 rounds up to X:15",   roundedMinute(9, 8)  == 15)
            expect("X:22 rounds down to X:15", roundedMinute(9, 22) == 15)
            expect("X:23 rounds up to X:30",   roundedMinute(9, 23) == 30)
            expect("X:37 rounds down to X:30", roundedMinute(9, 37) == 30)
            expect("X:38 rounds up to X:45",   roundedMinute(9, 38) == 45)
            expect("X:52 rounds down to X:45", roundedMinute(9, 52) == 45)
            expect("X:53 rounds up to next hour :00", roundedMinute(9, 53) == 0 && roundedHour(9, 53) == 10)
            expect("X:00 stays at X:00",       roundedMinute(9, 0)  == 0)
            expect("X:15 stays at X:15",       roundedMinute(9, 15) == 15)
            expect("X:30 stays at X:30",       roundedMinute(9, 30) == 30)
            expect("X:45 stays at X:45",       roundedMinute(9, 45) == 45)
        }

        suite("TimespanFormatter — format output") {
            func makeDate(hour: Int, minute: Int) -> Date {
                cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
            }

            let start = makeDate(hour: 9, minute: 3)   // rounds to 9:00am
            let end   = makeDate(hour: 16, minute: 47)  // rounds to 4:45pm

            let rangeStr = TimespanFormatter.format(first: start, last: end)
            expect("range includes start time", rangeStr.contains("9:00"))
            expect("range includes end time",   rangeStr.contains("4:45"))
            expect("range includes arrow",      rangeStr.contains("→"))

            let singleStr = TimespanFormatter.format(first: start, last: nil)
            expect("single entry shows start only", singleStr.contains("9:00"))
            expect("single entry has no arrow",     !singleStr.contains("→"))
        }

        suite("TimespanFormatter — timespan from entries") {
            expect("no entries returns nil", TimespanFormatter.timespan(from: []) == nil)
        }

        suite("UpdateChecker — version comparison") {
            expect("patch newer",  UpdateChecker.isNewer("1.1.3", than: "1.1.2"))
            expect("minor newer",  UpdateChecker.isNewer("1.2.0", than: "1.1.9"))
            expect("major newer",  UpdateChecker.isNewer("2.0.0", than: "1.9.9"))
            expect("same version", !UpdateChecker.isNewer("1.1.2", than: "1.1.2"))
            expect("older patch",  !UpdateChecker.isNewer("1.1.1", than: "1.1.2"))
            expect("older minor",  !UpdateChecker.isNewer("1.0.9", than: "1.1.0"))
            expect("older major",  !UpdateChecker.isNewer("1.9.9", than: "2.0.0"))
            expect("strips leading v", UpdateChecker.isNewer("v1.1.3", than: "1.1.2"))
            expect("both with v",  !UpdateChecker.isNewer("v1.1.2", than: "v1.1.2"))
        }

        suite("UpdateChecker — cache parsing") {
            // No cache file — returns nil
            let noCache = UpdateChecker.cachedLatest()
            // We can't control the cache file in tests, so just verify the function runs
            // and returns a valid shape when data exists (structural test only)
            let _ = noCache // suppresses unused warning; real check is that it doesn't crash
            expect("cachedLatest does not crash when file absent or present", true)
        }

        suite("UpdateChecker — hint") {
            // hint() returns nil when no PKG install (expected on dev machine)
            // and also when installed == latest; both cases return nil here
            let h = UpdateChecker.hint()
            expect("hint is nil on dev machine (no pkgutil receipt)", h == nil)
        }

        // MARK: - parseArgs

        suite("parseArgs — no args") {
            if case .empty = parseArgs([]) {
                expect("empty args → .empty", true)
            } else {
                expect("empty args → .empty", false)
            }
        }

        suite("parseArgs — help flags") {
            expect("'help' → .help",       { if case .help = parseArgs(["help"])     { return true }; return false }())
            expect("'--help' → .help",     { if case .help = parseArgs(["--help"])   { return true }; return false }())
            expect("'-h' → .help",         { if case .help = parseArgs(["-h"])       { return true }; return false }())
            expect("'--help' after cmd",   { if case .help = parseArgs(["add", "--help"]) { return true }; return false }())
            expect("'-h' after cmd",       { if case .help = parseArgs(["add", "-h"])    { return true }; return false }())
            expect("'--help' mid-args",    { if case .help = parseArgs(["add", "buy milk", "--help"]) { return true }; return false }())
            // 'help add' — first arg is 'help', second arg ignored; shows full help (Phase 4 will filter to subcommand)
            expect("'help add' → .help",   { if case .help = parseArgs(["help", "add"]) { return true }; return false }())
        }

        suite("parseArgs — version flags") {
            expect("'version' → .version",   { if case .version = parseArgs(["version"])   { return true }; return false }())
            expect("'--version' → .version", { if case .version = parseArgs(["--version"]) { return true }; return false }())
            expect("'-v' → .version",        { if case .version = parseArgs(["-v"])        { return true }; return false }())
            expect("'-v' after cmd",         { if case .version = parseArgs(["add", "-v"]) { return true }; return false }())
        }

        suite("parseArgs — content words not intercepted") {
            // bare 'help' in non-first position is content, not a flag
            if case .command(let cmd, let args) = parseArgs(["add", "Home", "help", "Joe", "with", "cleaning"]) {
                expect("'help' as content: cmd = add",   cmd == "add")
                expect("'help' as content: args intact", args == ["add", "Home", "help", "Joe", "with", "cleaning"])
            } else {
                expect("'help' as content word parses as .command", false)
                expect("'help' as content: args intact", false)
            }
            // bare 'version' in non-first position is content
            if case .command(_, let args) = parseArgs(["add", "version", "1.0"]) {
                expect("'version' as content: args intact", args == ["add", "version", "1.0"])
            } else {
                expect("'version' as content word parses as .command", false)
            }
        }

        suite("parseArgs — flag stripping") {
            if case .command(let cmd, let args) = parseArgs(["list", "Work"]) {
                expect("clean args: cmd = list",     cmd == "list")
                expect("clean args: args[0] = list", args[0] == "list")
                expect("clean args: args[1] = Work", args[1] == "Work")
            } else {
                expect("clean args parse as .command", false)
            }
        }

        print("\n\(passed + failed) tests: \(passed) passed, \(failed) failed")
        if failed > 0 { exit(1) }
    }
}

TestRunner().run()
