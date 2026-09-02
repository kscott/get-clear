// DateParser.swift
//
// Parses natural-language date strings into ParsedDate values.
// No Apple framework dependencies beyond Foundation — fully unit testable.
//
// Supported formats:
//   Relative days:  "today", "tomorrow"
//   Weekday names:  "monday" … "sunday"  (next future occurrence)
//   next/this:      "next friday", "this monday"  (same as bare weekday)
//   Month + day:    "march 15", "mar 15"  (rolls to next year if past)
//   Month+day+year: "march 10 2027", "march 10, 2027", "10 march 2027", "mar 20, 2026"
//   ISO date:       "2026-03-15"
//   US date:        "3/10/2027", "3/10/27"
//   Short date:     "3/15" or "3-15"     (rolls to next year if past)
//   Time only:      "3pm", "14:30"       (defaults to today)
//   Combined:       "tomorrow 3pm", "friday at 5pm", "march 15 9am"
//
// When no time is specified, hasTime is false and callers should treat the
// result as a date-only value — no alarm time is implied.
// When no date is specified (time-only input), hasDate is false.

import Foundation

public struct ParsedDate {
    public let date: Date
    /// True when the input explicitly included a time ("3pm", "at 14:30", etc.)
    public let hasTime: Bool
    /// True when the input included an explicit date (day, weekday, month+day, ISO).
    /// False when the input was time-only ("3pm"), in which case date defaults to today.
    public let hasDate: Bool

    public init(date: Date, hasTime: Bool, hasDate: Bool) {
        self.date = date
        self.hasTime = hasTime
        self.hasDate = hasDate
    }
}

private let weekdayNumbers = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
                              "thursday": 5, "friday": 6, "saturday": 7]
private let monthNumbers = ["january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
                            "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
                            "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6,
                            "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12]

public func parseDate(_ input: String) -> ParsedDate? {
    var s = input.lowercased().trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("on ") {
        s = String(s.dropFirst(3)).trimmingCharacters(in: .whitespaces)
    }
    let cal = Calendar.current
    let now = Date()
    var components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)

    let extracted = extractTimeComponents(from: s)
    let dayPart = extracted.dayPart
    let timePart = extracted.timePart
    components.hour = extracted.hour
    components.minute = extracted.minute

    let dayTrimmed = dayPart.trimmingCharacters(in: .whitespaces)
    guard applyDayPart(dayTrimmed, now: now, cal: cal, components: &components) else {
        return nil
    }

    guard let date = cal.date(from: components) else { return nil }
    return ParsedDate(date: date, hasTime: timePart != nil, hasDate: !dayTrimmed.isEmpty)
}

/// The day text with any time phrase removed, the resolved hour/minute (defaulting to 9:00 when
/// no time is present or parseable), and the raw matched time substring (nil when none found).
private struct ExtractedTime {
    let dayPart: String
    let hour: Int
    let minute: Int
    let timePart: String?
}

/// Extracts an "at 5pm" / "14:30" style time from `s`.
private func extractTimeComponents(from s: String) -> ExtractedTime {
    let timePatterns = [
        #"(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)"#,
        #"(?:at\s+)?(\d{1,2}):(\d{2})$"#
    ]

    var dayPart = s
    var timePart: String?

    for pattern in timePatterns {
        if let range = s.range(of: pattern, options: .regularExpression) {
            timePart = String(s[range])
            dayPart = s.replacingCharacters(in: range, with: "")
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: #"\bat\b,?"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            break
        }
    }

    var hour = 9
    var minute = 0
    if let timePart {
        let tp = timePart.replacingOccurrences(of: "at ", with: "")
        if let numRegex = try? NSRegularExpression(pattern: #"(\d{1,2})(?::(\d{2}))?\s*(am|pm)?"#),
           let match = numRegex.firstMatch(in: tp, range: NSRange(tp.startIndex..., in: tp))
        {
            let h = Int((tp as NSString).substring(with: match.range(at: 1))) ?? 9
            let m = match.range(at: 2).location != NSNotFound
                ? Int((tp as NSString).substring(with: match.range(at: 2))) ?? 0 : 0
            let ampm = match.range(at: 3).location != NSNotFound
                ? (tp as NSString).substring(with: match.range(at: 3)) : ""
            hour = ampm == "pm" && h < 12 ? h + 12 : ampm == "am" && h == 12 ? 0 : h
            minute = m
        }
    }
    return ExtractedTime(dayPart: dayPart, hour: hour, minute: minute, timePart: timePart)
}

/// Applies the day/date portion (today, tomorrow, a weekday, or a month/numeric date) to
/// `components`. Returns false when `dayTrimmed` doesn't match any recognized date form.
private func applyDayPart(_ dayTrimmed: String, now: Date, cal: Calendar, components: inout DateComponents) -> Bool {
    if dayTrimmed.isEmpty || dayTrimmed == "today" {
        return true
    }
    if dayTrimmed == "tomorrow" {
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: now) else { return false }
        let tc = cal.dateComponents([.year, .month, .day], from: tomorrow)
        components.year = tc.year
        components.month = tc.month
        components.day = tc.day
        return true
    }
    // "next friday", "this monday" — strip the prefix, same behaviour as bare weekday
    let bareWeekday = dayTrimmed.replacingOccurrences(
        of: #"^(?:next|this)\s+"#, with: "", options: .regularExpression
    )
    if let weekdayNum = weekdayNumbers[bareWeekday] {
        var dc = DateComponents()
        dc.weekday = weekdayNum
        if let next = cal.nextDate(after: now, matching: dc, matchingPolicy: .nextTime) {
            let nc = cal.dateComponents([.year, .month, .day], from: next)
            components.year = nc.year
            components.month = nc.month
            components.day = nc.day
        }
        return true
    }
    return applyMonthOrNumericDate(dayTrimmed, now: now, cal: cal, components: &components)
}

/// Handles "march 15", "march 10 2027" / "10 march 2027", and numeric slash/dash dates.
private func applyMonthOrNumericDate(
    _ dayTrimmed: String, now: Date, cal: Calendar, components: inout DateComponents
) -> Bool {
    let parts = dayTrimmed.split(separator: " ").map(String.init)
    switch parts.count {
    case 2:
        // "march 15" — roll to next year if past
        guard let monthNum = monthNumbers[parts[0]], let day = Int(parts[1]) else { return false }
        components.month = monthNum
        components.day = day
        if let d = cal.date(from: components), d < now {
            components.year = (components.year ?? 0) + 1
        }
        return true
    case 3:
        return applyMonthDayYear(parts, components: &components)
    case 1:
        return applyNumericDate(parts[0], now: now, cal: cal, components: &components)
    default:
        return false
    }
}

/// "march 10 2027", "march 10, 2027", "10 march 2027"
private func applyMonthDayYear(_ parts: [String], components: inout DateComponents) -> Bool {
    let p0 = parts[0].trimmingCharacters(in: CharacterSet(charactersIn: ","))
    let p1 = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: ","))
    if let monthNum = monthNumbers[p0], let day = Int(p1), let year = Int(parts[2]) {
        components.month = monthNum
        components.day = day
        components.year = year < 100 ? 2000 + year : year
        return true
    }
    if let day = Int(p0), let monthNum = monthNumbers[p1], let year = Int(parts[2]) {
        components.month = monthNum
        components.day = day
        components.year = year < 100 ? 2000 + year : year
        return true
    }
    return false
}

/// ISO/US numeric dates ("2026-03-15", "3/10/2027") and short dates ("3/15", "3-15").
private func applyNumericDate(_ token: String, now: Date, cal: Calendar, components: inout DateComponents) -> Bool {
    let numParts = token.components(separatedBy: CharacterSet(charactersIn: "/-"))
    if numParts.count == 3,
       let p0 = Int(numParts[0]), let p1 = Int(numParts[1]), let p2 = Int(numParts[2])
    {
        // Heuristic: first part > 31 → Y/M/D (ISO); otherwise → M/D/Y (US)
        let y, m, d: Int
        if p0 > 31 {
            (y, m, d) = (p0, p1, p2)
        } else {
            let yr = p2 < 100 ? 2000 + p2 : p2
            (y, m, d) = (yr, p0, p1)
        }
        components.year = y
        components.month = m
        components.day = d
        return true
    }
    if numParts.count == 2, let m = Int(numParts[0]), let d = Int(numParts[1]) {
        // "3/15" or "3-15" — roll to next year if past
        components.month = m
        components.day = d
        if let date = cal.date(from: components), date < now {
            components.year = (components.year ?? 0) + 1
        }
        return true
    }
    return false
}

public func formatDate(_ date: Date, showTime: Bool) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = showTime ? .short : .none
    return f.string(from: date)
}
