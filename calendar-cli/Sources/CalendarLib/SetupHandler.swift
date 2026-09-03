// SetupHandler.swift

import Foundation
import GetClearKit

// MARK: - Pure helpers (testable)

/// Parses user-supplied comma-separated tokens into matched calendar titles and unmatched tokens.
/// Tokens may be numeric (referring to position in `numbered`) or calendar-title strings.
public func parseCalendarTokens(
    tokens: [String],
    numbered: [(number: Int, title: String)],
    all: [CalendarItem]
) -> (matched: [String], unmatched: [String]) {
    var matched: [String] = []
    var unmatched: [String] = []
    for token in tokens {
        if let num = Int(token),
           let entry = numbered.first(where: { $0.number == num })
        {
            matched.append(entry.title)
        } else if let cal = all.first(where: { $0.title.lowercased() == token.lowercased() }) {
            matched.append(cal.title)
        } else {
            unmatched.append(token)
        }
    }
    return (matched, unmatched)
}

/// Serializes subset definitions to a TOML [subsets] block.
public func buildSubsetTOML(subsets: [(name: String, calendars: [String])]) -> String {
    var toml = "[subsets]\n"
    for (name, cals) in subsets {
        let quoted = cals.map { "\"\($0)\"" }.joined(separator: ", ")
        toml += "\(name) = [\(quoted)]\n"
    }
    return toml
}

/// Assigns sequential numbers to calendars sorted by source then title.
/// Returns (number, title) pairs for display and token matching.
public func numberCalendars(_ calendars: [CalendarItem]) -> [(number: Int, title: String)] {
    let sorted = calendars.sorted {
        let s0 = $0.source ?? ""
        let s1 = $1.source ?? ""
        return s0 == s1 ? $0.title < $1.title : s0 < s1
    }
    return sorted.enumerated().map { (number: $0.offset + 1, title: $0.element.title) }
}

// MARK: - Interactive entry point (not unit tested)

@discardableResult
public func handleSetup(args: [String], store: any CalendarStore) async throws -> String {
    _ = try parseCommand(
        Array(args.dropFirst()), shape: CalendarCommandShapes.setup, wrapError: CalendarHandlerError.init
    )
    let all = try await store.fetchCalendars()

    let configURL = CalendarConfig.configURL
    let configDir = configURL.deletingLastPathComponent()

    if FileManager.default.fileExists(atPath: configURL.path) {
        print("Existing config found — running setup will overwrite it.\n")
    }

    let numbered = numberCalendars(all)
    let grouped = Dictionary(grouping: all) { $0.source ?? "" }
    print("Available calendars:\n")
    var idx = 0
    for source in grouped.keys.sorted() {
        if !source.isEmpty { print("  \(source)") }
        for cal in (grouped[source] ?? []).sorted(by: { $0.title < $1.title }) {
            idx += 1
            print(String(format: "    %2d  \(calendarDot(hex: cal.color))\(cal.title)", idx))
        }
    }

    print("\nCreate subsets to group calendars (e.g. \"work\", \"personal\").")
    print("Enter calendar names or numbers, comma-separated. Press Enter with no name to finish.\n")

    var subsets: [(name: String, calendars: [String])] = []
    signal(SIGINT) { _ in print("\nCancelled.")
        exit(0)
    }

    while true {
        print("Subset name: ", terminator: "")
        fflush(stdout)
        guard let rawNameInput = readLine() else { print("\nCancelled.")
            break
        }
        let subsetName = sanitize(rawNameInput).lowercased()
        guard !subsetName.isEmpty else { break }

        print("Calendars for \"\(subsetName)\": ", terminator: "")
        fflush(stdout)
        guard let rawCalInput = readLine() else { print("\nCancelled.")
            break
        }
        let calInput = sanitize(rawCalInput)
        guard !calInput.trimmingCharacters(in: .whitespaces).isEmpty else {
            print("  No calendars entered — skipping\n")
            continue
        }

        let tokens = calInput.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let (calNames, unmatched) = parseCalendarTokens(tokens: tokens, numbered: numbered, all: all)

        if !unmatched.isEmpty {
            print("  Not found: \(unmatched.joined(separator: ", ")) — skipping those")
        }
        guard !calNames.isEmpty else {
            print("  No valid calendars — skipping\n")
            continue
        }

        let quoted = calNames.map { "\"\($0)\"" }.joined(separator: ", ")
        print("  → \(subsetName) = [\(quoted)]\n")
        subsets.append((name: subsetName, calendars: calNames))
    }

    guard !subsets.isEmpty else {
        return "\nNo subsets defined — nothing written."
    }

    let toml = buildSubsetTOML(subsets: subsets)
    do {
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        try toml.write(to: configURL, atomically: true, encoding: .utf8)
        var result = "Config written to \(configURL.path)"
        if let first = subsets.first { result += "\nTry it: calendar \(first.name) today" }
        return result
    } catch {
        fail("Could not write config: \(error.localizedDescription)")
    }
}

private func sanitize(_ s: String) -> String {
    String(s.unicodeScalars.filter { $0.value >= 32 && $0.value < 127 })
        .trimmingCharacters(in: .whitespaces)
}
