// RecapFormatter.swift
// Formats recap output for terminal display.

import Foundation
import EventKit
import GetClearKit

// MARK: - Calendar dot

func calendarDot(_ calendar: EKCalendar) -> String {
    guard ANSI.enabled else { return "  " }
    guard let cg = calendar.cgColor else { return "  " }
    let colorSpace = cg.colorSpace?.model
    let components = cg.components ?? []
    let r, g, b: Int
    if colorSpace == .rgb, components.count >= 3 {
        r = Int(components[0] * 255)
        g = Int(components[1] * 255)
        b = Int(components[2] * 255)
    } else if colorSpace == .monochrome, components.count >= 1 {
        let w = Int(components[0] * 255)
        r = w; g = w; b = w
    } else {
        return "  "
    }
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
        case .fromCalendar(let events):
            label = "From your calendar"
            items = events.map { $0.title ?? "(no title)" }
        case .tasksCompleted(let reminders):
            label = "Tasks completed"
            items = reminders.map { rem in
                let title = rem.title ?? "(no title)"
                if let list = rem.calendar?.title { return "\(title) [\(list)]" }
                return title
            }
        case .sent(let entries):
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
        if isToday && !fr018Active {
            return "Quiet so far. Ready for the next thing."
        } else {
            return "Nothing recorded \(rangeStr)."
        }
    }

    var lines: [String] = []

    if range.isSingleDay {
        var header = ActivityLogFormatter.dateHeader(for: dateUsed)
        if let ts = result.timespan { header += " · \(TimespanFormatter.format(first: ts.start, last: ts.end))" }
        lines.append(header)
        lines.append("")
        lines += formatRecapGroups(result.groups)
    } else {
        // Multi-day: group by calendar day, skip empty days
        var days: [Date] = []
        var daySet = Set<Date>()
        func registerDay(_ d: Date) {
            let day = cal.startOfDay(for: d)
            if daySet.insert(day).inserted { days.append(day) }
        }
        for group in result.groups {
            switch group {
            case .fromCalendar(let events):   events.forEach { registerDay($0.startDate) }
            case .tasksCompleted(let rems):   rems.forEach { if let cd = $0.completionDate { registerDay(cd) } }
            case .sent(let entries):          entries.forEach { registerDay($0.ts) }
            }
        }
        for (i, day) in days.sorted().enumerated() {
            if i > 0 { lines.append("") }
            lines.append(ActivityLogFormatter.dateHeader(for: day))
            lines.append("")
            var dayGroups: [RecapGroup] = []
            for group in result.groups {
                switch group {
                case .fromCalendar(let events):
                    let d = events.filter { cal.isDate($0.startDate, inSameDayAs: day) }
                    if !d.isEmpty { dayGroups.append(.fromCalendar(d)) }
                case .tasksCompleted(let rems):
                    let d = rems.filter { $0.completionDate.map { cal.isDate($0, inSameDayAs: day) } ?? false }
                    if !d.isEmpty { dayGroups.append(.tasksCompleted(d)) }
                case .sent(let entries):
                    let d = entries.filter { cal.isDate($0.ts, inSameDayAs: day) }
                    if !d.isEmpty { dayGroups.append(.sent(d)) }
                }
            }
            lines += formatRecapGroups(dayGroups)
        }
    }

    return lines.joined(separator: "\n")
}
