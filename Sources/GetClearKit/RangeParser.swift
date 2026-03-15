// RangeParser.swift
//
// Parses natural-language time range strings into ParsedRange values.
// No Apple framework dependencies beyond Foundation — fully unit testable.
//
// Supported formats:
//   Single day:     "today", "tomorrow", "yesterday"
//   Weekday:        "monday" … "sunday"  (next occurrence; today if today matches)
//   next/this:      "next friday", "this week" etc.
//   Month + day:    "march 15"           (rolls to next year if past)
//   ISO date:       "2026-03-15"
//   Short date:     "3/15", "3-15"       (rolls to next year if past)
//   Week span:      "week", "this week", "next week", "last week"
//   Month span:     "month", "this month", "next month", "last month"
//   N-day window:   "7d", "30d"          (today through today+N-1)
//   Explicit range: "<date> to <date>"   (any two single-date expressions)

import Foundation

public struct ParsedRange {
    public let start: Date
    public let end: Date
    /// True when the range covers exactly one calendar day.
    public let isSingleDay: Bool

    public init(start: Date, end: Date, isSingleDay: Bool) {
        self.start       = start
        self.end         = end
        self.isSingleDay = isSingleDay
    }
}

public func parseRange(_ input: String) -> ParsedRange? {
    let s   = input.lowercased().trimmingCharacters(in: .whitespaces)
    let cal = Calendar.current
    let now = Date()

    // Explicit range: "X to Y"
    if let toRange = s.range(of: #"\s+to\s+"#, options: .regularExpression) {
        let left  = String(s[..<toRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let right = String(s[toRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard let startDate = parseSingleDate(left,  cal: cal, now: now),
              let endDate   = parseSingleDate(right, cal: cal, now: now) else { return nil }
        return ParsedRange(start: cal.startOfDay(for: startDate),
                           end:   rangeEndOfDay(endDate, cal: cal),
                           isSingleDay: false)
    }

    // N-day window: "7d", "30d"
    if s.range(of: #"^\d+d$"#, options: .regularExpression) != nil {
        guard let n = Int(s.dropLast()), n > 0 else { return nil }
        let start = cal.startOfDay(for: now)
        let end   = cal.date(byAdding: .day, value: n - 1, to: start)!
        return ParsedRange(start: start, end: rangeEndOfDay(end, cal: cal), isSingleDay: n == 1)
    }

    // Strip optional "this " prefix before span keywords
    let stripped = s.replacingOccurrences(of: #"^this\s+"#, with: "", options: .regularExpression)

    switch stripped {
    case "week":
        let start = rangeWeekStart(of: now, cal: cal)
        let end   = cal.date(byAdding: .day, value: 6, to: start)!
        return ParsedRange(start: start, end: rangeEndOfDay(end, cal: cal), isSingleDay: false)
    case "next week":
        let start = cal.date(byAdding: .weekOfYear, value: 1, to: rangeWeekStart(of: now, cal: cal))!
        let end   = cal.date(byAdding: .day, value: 6, to: start)!
        return ParsedRange(start: start, end: rangeEndOfDay(end, cal: cal), isSingleDay: false)
    case "last week":
        let start = cal.date(byAdding: .weekOfYear, value: -1, to: rangeWeekStart(of: now, cal: cal))!
        let end   = cal.date(byAdding: .day, value: 6, to: start)!
        return ParsedRange(start: start, end: rangeEndOfDay(end, cal: cal), isSingleDay: false)
    case "month":
        let (start, end) = rangeMonthBounds(of: now, cal: cal)
        return ParsedRange(start: start, end: end, isSingleDay: false)
    case "next month":
        let firstOfNext = cal.date(from: cal.dateComponents([.year, .month],
                         from: cal.date(byAdding: .month, value: 1, to: now)!))!
        let (_, end) = rangeMonthBounds(of: firstOfNext, cal: cal)
        return ParsedRange(start: firstOfNext, end: end, isSingleDay: false)
    case "last month":
        let firstOfLast = cal.date(from: cal.dateComponents([.year, .month],
                         from: cal.date(byAdding: .month, value: -1, to: now)!))!
        let (_, end) = rangeMonthBounds(of: firstOfLast, cal: cal)
        return ParsedRange(start: firstOfLast, end: end, isSingleDay: false)
    default:
        break
    }

    // Single date
    guard let date = parseSingleDate(s, cal: cal, now: now) else { return nil }
    return ParsedRange(start: cal.startOfDay(for: date),
                       end:   rangeEndOfDay(date, cal: cal),
                       isSingleDay: true)
}

/// Parse a single date reference — used for standalone ranges and each side of "X to Y".
public func parseSingleDate(_ s: String, cal: Calendar, now: Date) -> Date? {
    let lower = s.lowercased().trimmingCharacters(in: .whitespaces)

    switch lower {
    case "today":     return now
    case "tomorrow":  return cal.date(byAdding: .day, value:  1, to: now)
    case "yesterday": return cal.date(byAdding: .day, value: -1, to: now)
    default: break
    }

    let weekdays = ["sunday":1,"monday":2,"tuesday":3,"wednesday":4,
                    "thursday":5,"friday":6,"saturday":7]
    let bare = lower.replacingOccurrences(of: #"^(?:next|this)\s+"#, with: "", options: .regularExpression)
    if let num = weekdays[bare] {
        if cal.component(.weekday, from: now) == num { return now }
        var dc = DateComponents(); dc.weekday = num
        return cal.nextDate(after: now, matching: dc, matchingPolicy: .nextTime)
    }

    let months = ["january":1,"february":2,"march":3,"april":4,"may":5,"june":6,
                  "july":7,"august":8,"september":9,"october":10,"november":11,"december":12]
    let parts = lower.split(separator: " ").map(String.init)

    if parts.count == 2, let monthNum = months[parts[0]], let day = Int(parts[1]) {
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.month = monthNum; comps.day = day
        if let d = cal.date(from: comps), d < cal.startOfDay(for: now) {
            comps.year = (comps.year ?? 0) + 1
        }
        return cal.date(from: comps)
    }

    if parts.count == 1 {
        let sep  = CharacterSet(charactersIn: "/-")
        let nums = lower.components(separatedBy: sep)
        if nums.count == 3, let y = Int(nums[0]), let m = Int(nums[1]), let d = Int(nums[2]) {
            var comps = DateComponents()
            comps.year = y; comps.month = m; comps.day = d
            return cal.date(from: comps)
        }
        if nums.count == 2, let m = Int(nums[0]), let d = Int(nums[1]) {
            var comps = cal.dateComponents([.year], from: now)
            comps.month = m; comps.day = d
            if let date = cal.date(from: comps), date < cal.startOfDay(for: now) {
                comps.year = (comps.year ?? 0) + 1
            }
            return cal.date(from: comps)
        }
    }

    return nil
}

// MARK: - Formatting

public func formatRangeDescription(_ range: ParsedRange) -> String {
    let cal = Calendar.current
    let f   = DateFormatter()
    if range.isSingleDay {
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: range.start)
    }
    let startYear = cal.component(.year, from: range.start)
    let endYear   = cal.component(.year, from: range.end)
    f.dateFormat  = startYear == endYear ? "MMM d" : "MMM d, yyyy"
    let startStr  = f.string(from: range.start)
    let endStr    = f.string(from: range.end)
    return "\(startStr) – \(endStr)"
}

// MARK: - Private helpers (prefixed to avoid collisions)

private func rangeEndOfDay(_ date: Date, cal: Calendar) -> Date {
    let start = cal.startOfDay(for: date)
    return cal.date(byAdding: DateComponents(day: 1, second: -1), to: start)!
}

private func rangeWeekStart(of date: Date, cal: Calendar) -> Date {
    let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    return cal.date(from: comps)!
}

private func rangeMonthBounds(of date: Date, cal: Calendar) -> (Date, Date) {
    let start = cal.date(from: cal.dateComponents([.year, .month], from: date))!
    let end   = cal.date(byAdding: DateComponents(month: 1, second: -1), to: start)!
    return (start, rangeEndOfDay(end, cal: cal))
}
