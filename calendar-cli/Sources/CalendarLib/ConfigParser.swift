// ConfigParser.swift
//
// Loads and parses ~/.config/calendar-cli/config.toml into a CalendarConfig.
// No EventKit dependency — kept in CalendarLib so it can be unit tested.
//
// Supported config format (TOML subset):
//
//   [subsets]
//   work     = ["Work", "Meetings", "Ken's Google Calendar"]
//   personal = ["Home", "Family", "Birthdays & Anniversaries"]
//
// Subset names are matched case-insensitively.

import Foundation

public struct CalendarConfig {
    /// Subset name (lowercased) → array of calendar titles to include
    public let subsets: [String: [String]]

    public static let empty = CalendarConfig(subsets: [:])

    public init(subsets: [String: [String]]) {
        self.subsets = subsets
    }
}

public func loadConfig() -> CalendarConfig {
    let configURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/calendar-cli/config.toml")
    guard let content = try? String(contentsOf: configURL, encoding: .utf8) else {
        return .empty
    }
    return parseConfig(content)
}

public func parseConfig(_ content: String) -> CalendarConfig {
    var subsets: [String: [String]] = [:]
    var inSubsets = false

    for line in content.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("#") || trimmed.isEmpty { continue }

        if trimmed == "[subsets]" {
            inSubsets = true
            continue
        }
        if trimmed.hasPrefix("[") {
            inSubsets = false
            continue
        }

        guard inSubsets, let eqIdx = trimmed.firstIndex(of: "=") else { continue }

        let key   = trimmed[..<eqIdx].trimmingCharacters(in: .whitespaces).lowercased()
        let value = trimmed[trimmed.index(after: eqIdx)...].trimmingCharacters(in: .whitespaces)
        let names = parseStringArray(value)

        if !key.isEmpty && !names.isEmpty {
            subsets[key] = names
        }
    }

    return CalendarConfig(subsets: subsets)
}

/// Extract quoted strings from a TOML inline array: ["foo", "bar with spaces", "baz"]
private func parseStringArray(_ s: String) -> [String] {
    var result: [String] = []
    let regex = try! NSRegularExpression(pattern: #""([^"]+)""#)
    let matches = regex.matches(in: s, range: NSRange(s.startIndex..., in: s))
    for match in matches {
        if let range = Range(match.range(at: 1), in: s) {
            result.append(String(s[range]))
        }
    }
    return result
}
