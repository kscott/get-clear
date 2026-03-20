import Foundation

/// Formats activity log entries for `what` and `get-clear what` output.
public struct ActivityLogFormatter {

    // MARK: - Per-tool `what`

    /// Format entries for a per-tool `<tool> what [range]` command.
    ///
    /// - Parameters:
    ///   - entries: Entries to display (already filtered to the tool)
    ///   - range: The parsed date range
    ///   - rangeStr: Original range argument (e.g. "yesterday", "this week") for empty state messages
    ///   - tool: Tool name for empty state messages (e.g. "reminders")
    ///   - dateUsed: The actual date whose entries are shown — differs from today only when
    ///               FR-018 has substituted a recent session from a prior day
    public static func perToolWhat(
        entries: [ActivityLogEntry],
        range: ParsedRange,
        rangeStr: String,
        tool: String,
        dateUsed: Date = Date()
    ) -> String {
        let cal = Calendar.current
        let isDefaultToday = rangeStr == "today"

        if entries.isEmpty {
            return emptyMessage(tool: tool, rangeStr: rangeStr)
        }

        if range.isSingleDay {
            // Single-day: one block of entries, header only if not today (or FR-018 substituted)
            let showHeader = !cal.isDateInToday(dateUsed)
            return formatBlock(entries: entries, date: dateUsed, showHeader: showHeader, includeTool: false)
        } else {
            // Multi-day: group by calendar day, header for each day, footer with coverage stats
            return formatMultiDay(entries: entries, range: range, includeTool: false)
        }
    }

    // MARK: - Suite-level `get-clear what`

    /// Format entries for the suite-level `get-clear what [range]` command.
    ///
    /// Same structure as per-tool but includes a tool column.
    public static func suiteWhat(
        entries: [ActivityLogEntry],
        range: ParsedRange,
        rangeStr: String,
        dateUsed: Date = Date()
    ) -> String {
        let cal = Calendar.current

        if entries.isEmpty {
            return rangeStr == "today"
                ? "Nothing recorded so far today."
                : "Nothing recorded \(rangeStr)."
        }

        if range.isSingleDay {
            let showHeader = !cal.isDateInToday(dateUsed)
            return formatBlock(entries: entries, date: dateUsed, showHeader: showHeader, includeTool: true)
        } else {
            return formatMultiDay(entries: entries, range: range, includeTool: true)
        }
    }

    // MARK: - Private helpers

    private static func emptyMessage(tool: String, rangeStr: String) -> String {
        if rangeStr == "today" {
            return "Nothing recorded in \(tool) today."
        } else {
            return "Nothing recorded in \(tool) \(rangeStr)."
        }
    }

    /// Format a single block of entries (one calendar day).
    private static func formatBlock(
        entries: [ActivityLogEntry],
        date: Date,
        showHeader: Bool,
        includeTool: Bool
    ) -> String {
        var lines: [String] = []
        if showHeader {
            lines.append(dateHeader(for: date))
            lines.append("")
        }
        for entry in entries {
            lines.append(formatEntry(entry, includeTool: includeTool))
        }
        return lines.joined(separator: "\n")
    }

    /// Format entries grouped by calendar day for multi-day ranges.
    private static func formatMultiDay(
        entries: [ActivityLogEntry],
        range: ParsedRange,
        includeTool: Bool
    ) -> String {
        let cal = Calendar.current

        // Group entries by calendar day
        var byDay: [(Date, [ActivityLogEntry])] = []
        for entry in entries {
            let day = cal.startOfDay(for: entry.ts)
            if let last = byDay.last, cal.isDate(last.0, inSameDayAs: day) {
                byDay[byDay.count - 1].1.append(entry)
            } else {
                byDay.append((day, [entry]))
            }
        }

        var lines: [String] = []
        for (index, (day, dayEntries)) in byDay.enumerated() {
            if index > 0 { lines.append("") }
            lines.append(dateHeader(for: day))
            lines.append("")
            for entry in dayEntries {
                lines.append(formatEntry(entry, includeTool: includeTool))
            }
        }

        // Footer: X of Y days recorded
        let totalDays = cal.dateComponents([.day], from: cal.startOfDay(for: range.start),
                                           to: cal.startOfDay(for: range.end)).day.map { $0 + 1 } ?? 1
        let recordedDays = byDay.count
        if totalDays > 1 {
            lines.append("")
            lines.append("\(recordedDays) of \(totalDays) days recorded.")
        }

        return lines.joined(separator: "\n")
    }

    /// Format a single log entry as a display line.
    private static func formatEntry(_ entry: ActivityLogEntry, includeTool: Bool) -> String {
        let time = timeFormatter().string(from: entry.ts)
        let paddedTime = String(repeating: " ", count: max(0, 7 - time.count)) + time
        let paddedCmd  = entry.cmd.padding(toLength: 6, withPad: " ", startingAt: 0)

        var parts = " \(paddedTime)  \(paddedCmd)"
        if includeTool {
            let paddedTool = entry.tool.padding(toLength: 9, withPad: " ", startingAt: 0)
            parts = " \(paddedTime)  \(paddedTool)  \(paddedCmd)"
        }
        parts += "  \(entry.desc)"
        if let container = entry.container {
            parts += "  [\(container)]"
        }
        return parts
    }

    /// Format a date as "Tuesday March 18".
    private static func dateHeader(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE MMMM d"
        return fmt.string(from: date)
    }

    private static func timeFormatter() -> DateFormatter {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"
        fmt.amSymbol = "am"
        fmt.pmSymbol = "pm"
        return fmt
    }
}
