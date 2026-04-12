// SetupCommand.swift
//
// Interactive guided setup for creating calendar subset config.

import Foundation
import EventKit
import CalendarLib
import GetClearKit

func runSetup(store: EKEventStore) {
    let all = store.calendars(for: .event)

    let configURL = CalendarConfig.configURL
    let configDir = configURL.deletingLastPathComponent()

    if FileManager.default.fileExists(atPath: configURL.path) {
        print("Existing config found — running setup will overwrite it.\n")
    }

    var numberedCals: [(Int, EKCalendar)] = []
    var n = 1
    let grouped = Dictionary(grouping: all) { $0.source.title }
    print("Available calendars:\n")
    for source in grouped.keys.sorted() {
        print("  \(source)")
        for cal in (grouped[source] ?? []).sorted(by: { $0.title < $1.title }) {
            print(String(format: "    %2d  \(colorDot(calendarColor(cal)))\(cal.title)", n))
            numberedCals.append((n, cal))
            n += 1
        }
    }

    print("\nCreate subsets to group calendars (e.g. \"work\", \"personal\").")
    print("Enter calendar names or numbers, comma-separated. Press Enter with no name to finish.\n")

    var subsets: [(String, [String])] = []

    signal(SIGINT) { _ in print("\nCancelled."); exit(0) }

    while true {
        print("Subset name: ", terminator: "")
        fflush(stdout)
        guard let rawNameInput = readLine() else { print("\nCancelled."); break }
        let nameInput  = String(rawNameInput.unicodeScalars.filter { $0.value >= 32 && $0.value < 127 })
        let subsetName = nameInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !subsetName.isEmpty else { break }

        print("Calendars for \"\(subsetName)\": ", terminator: "")
        fflush(stdout)
        guard let rawCalInput = readLine() else { print("\nCancelled."); break }
        let calInput = String(rawCalInput.unicodeScalars.filter { $0.value >= 32 && $0.value < 127 })
        guard !calInput.trimmingCharacters(in: .whitespaces).isEmpty else {
            print("  No calendars entered — skipping\n")
            continue
        }

        let tokens = calInput.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var calNames:  [String] = []
        var unmatched: [String] = []

        for token in tokens {
            if let num = Int(token), let match = numberedCals.first(where: { $0.0 == num }) {
                calNames.append(match.1.title)
            } else if let match = all.first(where: { $0.title.lowercased() == token.lowercased() }) {
                calNames.append(match.title)
            } else {
                unmatched.append(token)
            }
        }

        if !unmatched.isEmpty {
            print("  Not found: \(unmatched.joined(separator: ", ")) — skipping those")
        }
        guard !calNames.isEmpty else {
            print("  No valid calendars — skipping\n")
            continue
        }

        let quoted = calNames.map { "\"\($0)\"" }.joined(separator: ", ")
        print("  → \(subsetName) = [\(quoted)]\n")
        subsets.append((subsetName, calNames))
    }

    guard !subsets.isEmpty else {
        print("\nNo subsets defined — nothing written.")
        return
    }

    var toml = "[subsets]\n"
    for (name, cals) in subsets {
        let quoted = cals.map { "\"\($0)\"" }.joined(separator: ", ")
        toml += "\(name) = [\(quoted)]\n"
    }

    do {
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        try toml.write(to: configURL, atomically: true, encoding: .utf8)
        print("Config written to \(configURL.path)")
        if let first = subsets.first { print("Try it: calendar \(first.0) today") }
    } catch {
        fail("Could not write config: \(error.localizedDescription)")
    }
}
