// EventFormatter.swift
//
// Formats event data for display output.

import Foundation
import GetClearKit

/// Plain-data representation of an event for formatting.
/// Constructed from an EKEvent in CalendarCLI before calling formatter functions.
/// No EventKit or AppKit import required.
public struct EventDisplayData {
    public let title:         String
    public let start:         Date
    public let end:           Date?
    public let isAllDay:      Bool
    public let calendarName:  String
    public let calendarColor: (r: Int, g: Int, b: Int)?
    public let location:      String?

    public init(
        title:         String,
        start:         Date,
        end:           Date?,
        isAllDay:      Bool,
        calendarName:  String,
        calendarColor: (r: Int, g: Int, b: Int)?,
        location:      String? = nil
    ) {
        self.title         = title
        self.start         = start
        self.end           = end
        self.isAllDay      = isAllDay
        self.calendarName  = calendarName
        self.calendarColor = calendarColor
        self.location      = location
    }
}

// MARK: - Module-level formatters

let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    return f
}()

public let dayHeaderFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEEE, MMMM d"
    return f
}()

private let dayNameFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEE"
    return f
}()

private let monthDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM d"
    return f
}()

public let shortDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEE MMM d"
    return f
}()

public let eventDetailDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEE MMM d, yyyy"
    return f
}()

// MARK: - Public helpers

/// Formats a Date as a display time string, e.g. "2:00 PM".
public func formatEventTime(_ date: Date) -> String {
    timeFormatter.string(from: date)
}

/// Returns the ANSI true-color dot for a calendar color, or two spaces when color
/// is unavailable or ANSI is disabled.
public func colorDot(_ color: (r: Int, g: Int, b: Int)?) -> String {
    guard ANSI.enabled, let c = color else { return "  " }
    return "\u{001B}[38;2;\(c.r);\(c.g);\(c.b)m●\u{001B}[0m "
}

// MARK: - eventLine

/// Returns a single formatted event line for list/today/week/find output.
public func eventLine(for event: EventDisplayData) -> String {
    let timeCol: String
    if event.isAllDay {
        timeCol = " All day              "
    } else {
        let start = formatEventTime(event.start)
        let end   = event.end.map { formatEventTime($0) } ?? formatEventTime(event.start)
        timeCol = String(format: " %8@ – %-8@  ", start as CVarArg, end as CVarArg)
    }

    var label = ANSI.bold(event.title)
    if let loc = event.location, !loc.isEmpty {
        let firstLine = loc.components(separatedBy: "\n").first ?? loc
        let truncated = firstLine.count > 50 ? String(firstLine.prefix(50)) + "…" : firstLine
        label += ANSI.dim(" · " + truncated)
    }

    return "\(colorDot(event.calendarColor))\(timeCol)\(label)"
}

// MARK: - nextRelativeLabel


/// Returns a fixed-width (9-char) relative date label for use in `next` output.
/// Examples: "Today    ", "Tomorrow ", "Tue      ", "Jan 25   "
public func nextRelativeLabel(for date: Date, relativeTo now: Date) -> String {
    let cal = Calendar.current
    if cal.isDate(date, inSameDayAs: now) { return "Today    " }
    let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
    if cal.isDate(date, inSameDayAs: tomorrow) { return "Tomorrow " }
    let days = cal.dateComponents([.day],
                                  from: cal.startOfDay(for: now),
                                  to: cal.startOfDay(for: date)).day ?? 99
    let raw = days < 7 ? dayNameFormatter.string(from: date)
                       : monthDayFormatter.string(from: date)
    return raw.padding(toLength: 9, withPad: " ", startingAt: 0)
}

// MARK: - Grouped and flat printing

/// Prints events grouped by day with bold day headers.
public func printGrouped(_ events: [EventDisplayData]) {
    let cal     = Calendar.current
    let grouped = Dictionary(grouping: events) { cal.startOfDay(for: $0.start) }
    let days    = grouped.keys.sorted()
    for (i, day) in days.enumerated() {
        if i > 0 { print("") }
        print(ANSI.bold(dayHeaderFormatter.string(from: day)))
        let sorted = (grouped[day] ?? []).sorted { $0.start < $1.start }
        for event in sorted { print(eventLine(for: event)) }
    }
}

/// Prints events as a flat list, optionally preceded by a header line.
public func printFlat(_ events: [EventDisplayData], showHeader: Bool, header: String) {
    if showHeader { print(header) }
    for event in events { print(eventLine(for: event)) }
}
