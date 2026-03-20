import Foundation

/// Reads and filters activity log entries from daily log files.
public struct ActivityLogReader {

    static let defaultBaseDirectory: URL =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/get-clear/log")

    private static let validTools: Set<String> = ["reminders", "calendar", "contacts", "mail", "sms"]
    private static let validCmds:  Set<String> = ["add", "remove", "change", "rename", "done", "send"]

    // MARK: - Public API

    /// Returns all valid log entries within the given date range, optionally filtered by tool.
    /// Malformed lines, unknown tools, unknown commands, and empty descriptions are silently skipped.
    ///
    /// - Parameters:
    ///   - range: The date range to query (inclusive on both ends)
    ///   - tool: If non-nil, only entries for this tool are returned
    ///   - baseDirectory: Override for testing; defaults to `~/.local/share/get-clear/log`
    public static func entries(
        in range: ClosedRange<Date>,
        tool: String? = nil,
        baseDirectory: URL? = nil
    ) -> [ActivityLogEntry] {
        let base    = baseDirectory ?? defaultBaseDirectory
        let cal     = Calendar.current
        let decoder = JSONDecoder.logDecoder()
        var results: [ActivityLogEntry] = []

        var day    = cal.startOfDay(for: range.lowerBound)
        let endDay = cal.startOfDay(for: range.upperBound)

        while day <= endDay {
            let dateStr = ISO8601DateFormatter.logFileDateString(day)
            let fileURL = base.appendingPathComponent("\(dateStr).log")

            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
                    guard
                        let data  = line.data(using: .utf8),
                        let entry = try? decoder.decode(ActivityLogEntry.self, from: data),
                        validTools.contains(entry.tool),
                        validCmds.contains(entry.cmd),
                        !entry.desc.isEmpty,
                        entry.ts >= range.lowerBound,
                        entry.ts <= range.upperBound
                    else { continue }
                    if let filter = tool, entry.tool != filter { continue }
                    results.append(entry)
                }
            }

            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        return results.sorted { $0.ts < $1.ts }
    }

    /// Like `entries(in:tool:baseDirectory:)` but implements FR-018:
    /// if today has no entries and the most recent log entry across all files
    /// was written within 3 hours of `now`, returns that day's entries instead.
    ///
    /// The returned `dateUsed` is the actual date of the entries shown —
    /// callers should display it as a date header to make any substitution transparent.
    ///
    /// - Parameters:
    ///   - range: The originally requested date range (typically today)
    ///   - now: Current time; injectable for testing (defaults to `Date()`)
    ///   - baseDirectory: Override for testing
    public static func entriesForDisplay(
        in range: ClosedRange<Date>,
        now: Date = Date(),
        baseDirectory: URL? = nil
    ) -> (entries: [ActivityLogEntry], dateUsed: Date) {
        let base   = baseDirectory ?? defaultBaseDirectory
        let result = entries(in: range, tool: nil, baseDirectory: base)

        if !result.isEmpty {
            return (result, now)
        }

        // FR-018: today is empty — check for a recent session
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: base, includingPropertiesForKeys: nil
        ) else { return ([], now) }

        // Sort descending (lexicographic on YYYY-MM-DD = chronological)
        let logFiles = fileURLs
            .filter { $0.pathExtension == "log" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }

        let decoder      = JSONDecoder.logDecoder()
        let threeHoursAgo = now.addingTimeInterval(-3 * 3600)
        let cal          = Calendar.current

        for fileURL in logFiles {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

            // Find the most recent valid entry in this file
            var fileEntries: [ActivityLogEntry] = []
            for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
                guard
                    let data  = line.data(using: .utf8),
                    let entry = try? decoder.decode(ActivityLogEntry.self, from: data),
                    validTools.contains(entry.tool),
                    !entry.desc.isEmpty
                else { continue }
                fileEntries.append(entry)
            }

            guard let lastEntry = fileEntries.max(by: { $0.ts < $1.ts }) else { continue }

            if lastEntry.ts >= threeHoursAgo {
                // Within 3 hours — return all valid entries from this file.
                // dateUsed is derived from the file name, not the entry timestamp — the file
                // date is the authority on which calendar day to display in the header.
                let filename = fileURL.deletingPathExtension().lastPathComponent
                let fileFmt  = DateFormatter()
                fileFmt.dateFormat = "yyyy-MM-dd"
                let fileDate = fileFmt.date(from: filename) ?? lastEntry.ts
                return (fileEntries.sorted { $0.ts < $1.ts }, fileDate)
            }

            // Most recent file had a last entry > 3 hours ago — treat today as fresh start
            break
        }

        return ([], now)
    }
}
