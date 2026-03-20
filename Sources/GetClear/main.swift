// main.swift
//
// Entry point for the get-clear suite binary.
// Dispatches suite-level commands: what, recap.

import Foundation
import EventKit
import GetClearKit

let version = "1.0.0"
let args    = Array(CommandLine.arguments.dropFirst())

func usage() -> Never {
    print("""
    get-clear \(version) — Your commitments, your contacts, your communications

    Usage:
      get-clear what [range]          # Everything across all tools
      get-clear recap [range]         # Where you showed up (coming soon)

    Feedback: https://github.com/kscott/get-clear/issues
    """)
    exit(0)
}

// MARK: - Recap formatting

func recapDateHeader(for date: Date) -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "EEEE MMMM d"
    return fmt.string(from: date)
}

func formatTimespanResult(_ ts: TimespanResult) -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "h:mma"
    fmt.amSymbol = "am"
    fmt.pmSymbol = "pm"
    let start = fmt.string(from: ts.start)
    if let end = ts.end {
        return "\(start) → \(fmt.string(from: end))"
    }
    return start
}

func formatSentItem(_ entry: ActivityLogEntry) -> String {
    switch entry.tool {
    case "mail":
        let recipient = entry.desc.components(separatedBy: " Re: ").first ?? entry.desc
        return "Email to \(recipient)"
    case "sms":
        let name = entry.desc.components(separatedBy: ": ").first ?? entry.desc
        return "Text to \(name)"
    default:
        return entry.desc
    }
}

/// Format one set of recap groups into display lines (no date header — caller adds it).
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

    // Empty state
    if result.isEmpty {
        if isToday && !fr018Active {
            return "Quiet so far. Ready for the next thing."
        } else {
            return "Nothing recorded \(rangeStr)."
        }
    }

    var lines: [String] = []

    if range.isSingleDay {
        // Header: always show date for recap; append timespan if present
        var header = recapDateHeader(for: dateUsed)
        if let ts = result.timespan { header += " · \(formatTimespanResult(ts))" }
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
            lines.append(recapDateHeader(for: day))
            lines.append("")
            // Filter each group to this day
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

// MARK: - Dispatch

guard let cmd = args.first else { usage() }
if isVersionFlag(cmd) { print(version); exit(0) }
if isHelpFlag(cmd)    { usage() }

switch cmd {

case "what":
    let rangeStr = args.count > 1 ? Array(args.dropFirst()).joined(separator: " ") : "today"
    guard let range = parseRange(rangeStr) else { fail("Unrecognised range: \(rangeStr)") }
    let isToday = rangeStr == "today"
    let entries: [ActivityLogEntry]
    var dateUsed = Date()
    if isToday {
        let result = ActivityLogReader.entriesForDisplay(in: range.start...range.end)
        entries  = result.entries
        dateUsed = result.dateUsed
    } else {
        entries = ActivityLogReader.entries(in: range.start...range.end)
    }
    print(ActivityLogFormatter.suiteWhat(entries: entries, range: range, rangeStr: rangeStr,
                                         dateUsed: dateUsed))

case "recap":
    let rangeStr = args.count > 1 ? Array(args.dropFirst()).joined(separator: " ") : "today"
    guard let range = parseRange(rangeStr) else { fail("Unrecognised range: \(rangeStr)") }
    let isToday = rangeStr == "today"

    // FR-018: for today, check if we should substitute a recent prior day
    var effectiveRange = range.start...range.end
    var dateUsed       = range.start   // default: representative date for single-day header
    if isToday {
        let logResult = ActivityLogReader.entriesForDisplay(in: range.start...range.end)
        dateUsed = logResult.dateUsed
        if !Calendar.current.isDateInToday(dateUsed) {
            let cal      = Calendar.current
            let dayStart = cal.startOfDay(for: dateUsed)
            let dayEnd   = cal.date(byAdding: .day, value: 1, to: dayStart)!.addingTimeInterval(-1)
            effectiveRange = dayStart...dayEnd
        }
    }

    let sem   = DispatchSemaphore(value: 0)
    let store = EKEventStore()
    RecapAggregator.fetch(in: effectiveRange, store: store) { result in
        print(formatRecap(result, range: range, rangeStr: rangeStr,
                          isToday: isToday, dateUsed: dateUsed))
        sem.signal()
    }
    sem.wait()

default:
    usage()
}
