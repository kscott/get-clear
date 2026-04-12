// EventDateTime.swift
//
// Parses a date/time string into structured start/end/isAllDay values for calendar add.

import Foundation
import GetClearKit

public struct EventDateTime {
    public let start:    Date
    public let end:      Date?
    public let isAllDay: Bool

    public init(start: Date, end: Date?, isAllDay: Bool) {
        self.start    = start
        self.end      = end
        self.isAllDay = isAllDay
    }
}

/// Parses a date/time string for `calendar add`.
///
/// Handles:
///   "march 15"              → all-day event on March 15
///   "tomorrow 2pm to 3pm"   → timed event, explicit end
///   "today 9:30am to 11am"  → timed event with minutes, explicit end
///   "monday at 2pm"         → timed event, 1-hour default duration
///   "2pm to 3pm"            → timed event today (no date prefix)
///
/// The `relativeTo` parameter anchors all relative date calculations, making
/// the function testable with a fixed reference date.
private let timeTokenRegex = try! NSRegularExpression(
    pattern: #"\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b"#, options: .caseInsensitive)

public func parseEventDateTime(_ input: String, relativeTo now: Date = Date()) -> EventDateTime? {
    let cal = Calendar.current

    let timeMatches = timeTokenRegex.matches(in: input, range: NSRange(input.startIndex..., in: input))

    func extractHourMinute(_ m: NSTextCheckingResult) -> (Int, Int)? {
        guard let hourRange = Range(m.range(at: 1), in: input),
              let hour = Int(input[hourRange]) else { return nil }
        let minute: Int
        if let minRange = Range(m.range(at: 2), in: input) { minute = Int(input[minRange]) ?? 0 }
        else { minute = 0 }
        var h = hour
        if let apRange = Range(m.range(at: 3), in: input) {
            let ap = input[apRange].lowercased()
            if ap == "pm" && h < 12 { h += 12 }
            if ap == "am" && h == 12 { h = 0 }
        }
        return (h, minute)
    }

    if timeMatches.isEmpty {
        // All-day: parse the entire input as a date
        let trimmed = input.lowercased().trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let date = parseSingleDate(trimmed, cal: cal, now: now) else { return nil }
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: DateComponents(day: 1, second: -1), to: start)
        return EventDateTime(start: start, end: end, isAllDay: true)
    }

    // Date part = everything before the first time token
    let firstTimeRange = Range(timeMatches[0].range, in: input)!
    let datePart = String(input[..<firstTimeRange.lowerBound])
        .replacingOccurrences(of: #"\bat\b"#, with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespaces)

    let baseDate: Date
    if datePart.isEmpty {
        baseDate = now
    } else {
        guard let d = parseSingleDate(datePart.lowercased(), cal: cal, now: now) else { return nil }
        baseDate = d
    }

    guard let (startH, startM) = extractHourMinute(timeMatches[0]) else { return nil }
    var startComps = cal.dateComponents([.year, .month, .day], from: baseDate)
    startComps.hour = startH; startComps.minute = startM
    guard let start = cal.date(from: startComps) else { return nil }

    let end: Date?
    if timeMatches.count >= 2, let (endH, endM) = extractHourMinute(timeMatches[1]) {
        var endComps = startComps
        endComps.hour = endH; endComps.minute = endM
        end = cal.date(from: endComps)
    } else {
        end = cal.date(byAdding: .hour, value: 1, to: start)
    }

    return EventDateTime(start: start, end: end, isAllDay: false)
}
