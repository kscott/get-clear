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

/// Outcome of prompting for one subset name.
public enum SetupNameOutcome: Equatable {
    /// EOF (e.g. Ctrl-D) while reading the name.
    case cancelled
    /// The user pressed Enter with no name — the normal way to end the session.
    case finished
    /// A non-empty name was given; ready to prompt for its calendars.
    case proceed(subsetName: String)
}

/// Decides the outcome of a subset-name prompt. Pure — no I/O.
public func setupNameOutcome(_ rawInput: String?) -> SetupNameOutcome {
    guard let rawInput else { return .cancelled }
    let subsetName = sanitize(rawInput).lowercased()
    guard !subsetName.isEmpty else { return .finished }
    return .proceed(subsetName: subsetName)
}

/// Outcome of prompting for one subset's calendars.
public enum SetupCalendarOutcome: Equatable {
    /// EOF (e.g. Ctrl-D) while reading the calendar list.
    case cancelled
    /// The input was empty (or whitespace-only) after trimming.
    case emptyInput
    /// None of the given tokens matched a calendar.
    case noValidCalendars(unmatched: [String])
    /// At least one token matched; `unmatched` lists any that didn't (may be empty).
    case subsetAdded(calendars: [String], unmatched: [String])
}

/// Decides the outcome of a calendar-list prompt, given the raw (unsanitized) input and the
/// available calendars for token matching. Pure — no I/O.
public func setupCalendarOutcome(
    _ rawInput: String?,
    numbered: [(number: Int, title: String)],
    all: [CalendarItem]
) -> SetupCalendarOutcome {
    guard let rawInput else { return .cancelled }
    let calInput = sanitize(rawInput)
    guard !calInput.trimmingCharacters(in: .whitespaces).isEmpty else { return .emptyInput }

    let tokens = calInput.components(separatedBy: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }

    let (calNames, unmatched) = parseCalendarTokens(tokens: tokens, numbered: numbered, all: all)
    guard !calNames.isEmpty else { return .noValidCalendars(unmatched: unmatched) }
    return .subsetAdded(calendars: calNames, unmatched: unmatched)
}

/// Writes the subset TOML to `configURL` (creating `configDir` if needed) and returns the
/// confirmation message. `configURL`/`configDir` are parameters — never the hardcoded
/// `~/.config/calendar-cli/config.toml` global directly — so this is testable against a
/// temp directory without ever touching a real user config.
public func writeSetupConfig(
    subsets: [(name: String, calendars: [String])], configURL: URL, configDir: URL
) throws -> String {
    let toml = buildSubsetTOML(subsets: subsets)
    try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
    try toml.write(to: configURL, atomically: true, encoding: .utf8)
    var result = "Config written to \(configURL.path)"
    if let first = subsets.first { result += "\nTry it: calendar \(first.name) today" }
    return result
}

// MARK: - Interactive entry point (not unit tested — readLine/print/SIGINT are process-level)

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
    print(formatAvailableCalendars(all))

    print("\nCreate subsets to group calendars (e.g. \"work\", \"personal\").")
    print("Enter calendar names or numbers, comma-separated. Press Enter with no name to finish.\n")

    signal(SIGINT) { _ in print("\nCancelled.")
        exit(0)
    }

    let subsets = runInteractiveSetupLoop(numbered: numbered, all: all)

    guard !subsets.isEmpty else {
        return "\nNo subsets defined — nothing written."
    }

    do {
        return try writeSetupConfig(subsets: subsets, configURL: configURL, configDir: configDir)
    } catch {
        throw CalendarHandlerError("Could not write config: \(error.localizedDescription)")
    }
}

/// Formats the numbered "Available calendars" listing, grouped by source.
public func formatAvailableCalendars(_ all: [CalendarItem]) -> String {
    let grouped = Dictionary(grouping: all) { $0.source ?? "" }
    var lines = ["Available calendars:\n"]
    var idx = 0
    for source in grouped.keys.sorted() {
        if !source.isEmpty { lines.append("  \(source)") }
        for cal in (grouped[source] ?? []).sorted(by: { $0.title < $1.title }) {
            idx += 1
            lines.append(String(format: "    %2d  \(calendarDot(hex: cal.color))\(cal.title)", idx))
        }
    }
    return lines.joined(separator: "\n")
}

/// Drives the readLine/print loop that prompts for one subset at a time, using
/// `setupNameOutcome`/`setupCalendarOutcome` for the actual decisions. Returns the subsets
/// the user defined.
private func runInteractiveSetupLoop(
    numbered: [(number: Int, title: String)], all: [CalendarItem]
) -> [(name: String, calendars: [String])] {
    var subsets: [(name: String, calendars: [String])] = []

    setupLoop: while true {
        print("Subset name: ", terminator: "")
        fflush(stdout)
        let subsetName: String
        switch setupNameOutcome(readLine()) {
        case .cancelled:
            print("\nCancelled.")
            break setupLoop
        case .finished:
            break setupLoop
        case let .proceed(name):
            subsetName = name
        }

        print("Calendars for \"\(subsetName)\": ", terminator: "")
        fflush(stdout)
        switch setupCalendarOutcome(readLine(), numbered: numbered, all: all) {
        case .cancelled:
            print("\nCancelled.")
            break setupLoop
        case .emptyInput:
            print("  No calendars entered — skipping\n")
        case let .noValidCalendars(unmatched):
            printUnmatched(unmatched)
            print("  No valid calendars — skipping\n")
        case let .subsetAdded(calNames, unmatched):
            printUnmatched(unmatched)
            let quoted = calNames.map { "\"\($0)\"" }.joined(separator: ", ")
            print("  → \(subsetName) = [\(quoted)]\n")
            subsets.append((name: subsetName, calendars: calNames))
        }
    }

    return subsets
}

private func printUnmatched(_ unmatched: [String]) {
    guard !unmatched.isEmpty else { return }
    print("  Not found: \(unmatched.joined(separator: ", ")) — skipping those")
}

private func sanitize(_ s: String) -> String {
    String(s.unicodeScalars.filter { $0.value >= 32 && $0.value < 127 })
        .trimmingCharacters(in: .whitespaces)
}
