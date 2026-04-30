// EventFormatter.swift
// Formats EventItem data for display output.

import Foundation
import GetClearKit

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

public func formatEventTime(_ date: Date) -> String {
    timeFormatter.string(from: date)
}

public func calendarDot(hex: String?, ansiEnabled: Bool = ANSI.enabled) -> String {
    guard ansiEnabled, let hex, hex.count == 6 else { return "  " }
    guard let r = UInt8(hex.prefix(2), radix: 16),
          let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
          let b = UInt8(hex.dropFirst(4).prefix(2), radix: 16) else { return "  " }
    return "\u{001B}[38;2;\(r);\(g);\(b)m●\u{001B}[0m "
}

// MARK: - eventLine

public func eventLine(for event: EventItem) -> String {
    let timeCol: String
    if event.isAllDay {
        timeCol = " All day              "
    } else {
        let start = formatEventTime(event.startDate)
        let end = event.endDate.map { formatEventTime($0) } ?? formatEventTime(event.startDate)
        timeCol = String(format: " %8@ – %-8@  ", start as CVarArg, end as CVarArg)
    }

    var label = ANSI.bold(event.title)
    if let loc = event.location, !loc.isEmpty {
        let firstLine = loc.components(separatedBy: "\n").first ?? loc
        let truncated = firstLine.count > 50 ? String(firstLine.prefix(50)) + "…" : firstLine
        label += ANSI.dim(" · " + truncated)
    }

    return "\(calendarDot(hex: event.calendarColor))\(timeCol)\(label)"
}

// MARK: - nextRelativeLabel

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

// MARK: - Ambiguous match formatting

/// Returns the disambiguation message shown when multiple events match a title lookup.
func formatAmbiguous(_ matches: [EventItem], title: String, command: String) -> String {
    var lines = ["Multiple events match '\(title)':"]
    for e in matches {
        let dateStr = shortDateFormatter.string(from: e.startDate)
        let timeStr = e.isAllDay ? "all day" : formatEventTime(e.startDate)
        lines.append("  \(dateStr)  \(timeStr)  \(e.title)")
    }
    lines.append("Add a date to narrow the search, e.g.: calendar \(command) \"\(title)\" tomorrow")
    return lines.joined(separator: "\n")
}

// MARK: - Grouped and flat output

public func formatGrouped(_ events: [EventItem]) -> String {
    let cal = Calendar.current
    let grouped = Dictionary(grouping: events) { cal.startOfDay(for: $0.startDate) }
    let days = grouped.keys.sorted()
    return days.enumerated().map { i, day in
        let header = ANSI.bold(dayHeaderFormatter.string(from: day))
        let sorted = (grouped[day] ?? []).sorted { $0.startDate < $1.startDate }
        let lines = sorted.map { eventLine(for: $0) }
        return (i > 0 ? "\n" : "") + header + "\n" + lines.joined(separator: "\n")
    }.joined()
}

public func formatFlat(_ events: [EventItem], showHeader: Bool, header: String) -> String {
    var lines: [String] = []
    if showHeader { lines.append(header) }
    lines.append(contentsOf: events.map { eventLine(for: $0) })
    return lines.joined(separator: "\n")
}
