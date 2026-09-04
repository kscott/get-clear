// RecapFormatter.swift
// Formats recap output for terminal display.

import AppleEventKitSupport
import EventKit
import Foundation
import GetClearKit

// MARK: - Calendar dot

func calendarDot(_ calendar: EKCalendar) -> String {
    guard ANSI.enabled, let (r, g, b) = rgbComponents(from: calendar.cgColor) else { return "  " }
    return "\u{001B}[38;2;\(r);\(g);\(b)m●\u{001B}[0m "
}

// MARK: - Group and recap formatting

func formatSentItem(_ entry: ActivityLogEntry) -> String {
    switch entry.tool {
    case "mail":
        let recipient = entry.desc.components(separatedBy: " Re: ").first ?? entry.desc
        return "Email to \(recipient)"
    case "sms", "text":
        let name = entry.desc.components(separatedBy: ": ").first ?? entry.desc
        return "Text to \(name)"
    default:
        return entry.desc
    }
}

/// Formats one set of recap groups into display lines. Caller is responsible for any date header.
func formatRecapGroups(_ groups: [RecapGroup]) -> [String] {
    let labelWidth = 20
    var lines: [String] = []
    for group in groups {
        let label: String
        let items: [String]
        switch group {
        case let .fromCalendar(events):
            label = "From your calendar"
            items = events.map { $0.title ?? "(no title)" }
        case let .tasksCompleted(reminders):
            label = "Tasks completed"
            items = reminders.map { rem in
                let title = rem.title ?? "(no title)"
                if let list = rem.calendar?.title { return "\(title) [\(list)]" }
                return title
            }
        case let .sent(entries):
            label = "Sent"
            items = entries.map { formatSentItem($0) }
        }
        guard !items.isEmpty else { continue }
        let paddedLabel = label.padding(toLength: labelWidth, withPad: " ", startingAt: 0)
        lines.append("  \(paddedLabel) \(items.joined(separator: " · "))")
    }
    return lines
}

func formatRecap(
    _ result: RecapResult,
    range: ParsedRange,
    rangeStr: String,
    isToday: Bool,
    dateUsed: Date
) -> String {
    let cal = Calendar.current
    let fr018Active = isToday && !cal.isDateInToday(dateUsed)

    if result.isEmpty {
        if isToday, !fr018Active {
            return "Quiet so far. Ready for the next thing."
        } else {
            return "Nothing recorded \(rangeStr)."
        }
    }

    if range.isSingleDay {
        var lines: [String] = []
        var header = ActivityLogFormatter.dateHeader(for: dateUsed)
        if let ts = result.timespan { header += " · \(TimespanFormatter.format(first: ts.start, last: ts.end))" }
        lines.append(header)
        lines.append("")
        lines += formatRecapGroups(result.groups)
        return lines.joined(separator: "\n")
    }

    return formatMultiDayRecap(result.groups, cal: cal).joined(separator: "\n")
}

/// Groups recap items by calendar day (skipping empty days) and formats each day's block,
/// separated by a blank line between days. Extracted from formatRecap to keep its cyclomatic
/// complexity down — this is the multi-day-only branch.
private func formatMultiDayRecap(_ groups: [RecapGroup], cal: Calendar) -> [String] {
    var days: [Date] = []
    var daySet = Set<Date>()
    func registerDay(_ d: Date) {
        let day = cal.startOfDay(for: d)
        if daySet.insert(day).inserted { days.append(day) }
    }
    for group in groups {
        switch group {
        case let .fromCalendar(events): events.forEach { registerDay($0.startDate) }
        case let .tasksCompleted(rems): rems.forEach { if let cd = $0.completionDate { registerDay(cd) } }
        case let .sent(entries): entries.forEach { registerDay($0.ts) }
        }
    }

    var lines: [String] = []
    for (i, day) in days.sorted().enumerated() {
        if i > 0 { lines.append("") }
        lines.append(ActivityLogFormatter.dateHeader(for: day))
        lines.append("")
        lines += formatRecapGroups(dayGroups(from: groups, on: day, cal: cal))
    }
    return lines
}

/// Filters each RecapGroup down to just the items that fall on `day`, dropping any group left empty.
private func dayGroups(from allGroups: [RecapGroup], on day: Date, cal: Calendar) -> [RecapGroup] {
    var filtered: [RecapGroup] = []
    for group in allGroups {
        switch group {
        case let .fromCalendar(events):
            let d = events.filter { cal.isDate($0.startDate, inSameDayAs: day) }
            if !d.isEmpty { filtered.append(.fromCalendar(d)) }
        case let .tasksCompleted(rems):
            let d = rems.filter { $0.completionDate.map { cal.isDate($0, inSameDayAs: day) } ?? false }
            if !d.isEmpty { filtered.append(.tasksCompleted(d)) }
        case let .sent(entries):
            let d = entries.filter { cal.isDate($0.ts, inSameDayAs: day) }
            if !d.isEmpty { filtered.append(.sent(d)) }
        }
    }
    return filtered
}
