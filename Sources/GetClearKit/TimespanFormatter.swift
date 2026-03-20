import Foundation

/// Formats timespans for recap output.
/// Rounds all timestamps to the nearest 15 minutes — honest about approximation.
public struct TimespanFormatter {

    // MARK: - Rounding

    /// Rounds a date to the nearest 15-minute interval.
    /// Midpoint (7.5 min) rounds up: X:07 → X:00, X:08 → X:15.
    public static func roundTo15Minutes(_ date: Date) -> Date {
        let cal    = Calendar.current
        let minute = cal.component(.minute, from: date)
        let roundedMinutes = Int((Double(minute) / 15.0).rounded()) * 15

        var components  = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        components.second = 0
        if roundedMinutes == 60 {
            components.minute = 0
            components.hour   = (components.hour ?? 0) + 1
        } else {
            components.minute = roundedMinutes
        }
        return cal.date(from: components) ?? date
    }

    // MARK: - Formatting

    /// Formats a timespan as "9:00am → 4:45pm" (two entries) or "9:00am" (one entry).
    /// Both timestamps are rounded to 15 minutes before formatting.
    public static func format(first: Date, last: Date?) -> String {
        let fmt       = timeFormatter()
        let startStr  = fmt.string(from: roundTo15Minutes(first))
        if let last = last {
            let endStr = fmt.string(from: roundTo15Minutes(last))
            return "\(startStr) → \(endStr)"
        }
        return startStr
    }

    /// Returns the timespan (first and last ts, rounded) from a set of entries.
    /// Returns nil if entries is empty; `end` is nil when there is only one entry.
    public static func timespan(from entries: [ActivityLogEntry]) -> (start: Date, end: Date?)? {
        guard !entries.isEmpty else { return nil }
        let sorted = entries.sorted { $0.ts < $1.ts }
        let start  = roundTo15Minutes(sorted.first!.ts)
        let end    = sorted.count > 1 ? roundTo15Minutes(sorted.last!.ts) : nil
        return (start, end)
    }

    // MARK: - Private

    private static func timeFormatter() -> DateFormatter {
        let fmt      = DateFormatter()
        fmt.dateFormat = "h:mma"
        fmt.amSymbol = "am"
        fmt.pmSymbol = "pm"
        return fmt
    }
}
