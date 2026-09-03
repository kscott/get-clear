// SetupCommand.swift
// handleSetup() dispatches the setup command; pickAndSaveCalendars() runs the interactive picker.

import EventKit
import Foundation
import GetClearKit

/// Top-level dispatch for the setup command.
func handleSetup() async {
    if await pickAndSaveCalendars() { print("Try it: get-clear recap") }
}

/// Presents the calendar picker and writes the recap config.
/// Returns true if config was successfully written, false if cancelled or no valid input.
func pickAndSaveCalendars() async -> Bool {
    // Install SIGINT handler here rather than at the call site — setup is the only command
    // that blocks on user input, so this is the only place where Ctrl-C needs clean handling.
    installCancelOnInterrupt()
    let store = EKEventStore()

    guard await (try? store.requestFullAccessToEvents()) == true else {
        fail("Calendar access required for setup")
    }

    let all = store.calendars(for: .event)
    let grouped = Dictionary(grouping: all) { $0.source.title }

    let configURL = getClearConfigURL
    if FileManager.default.fileExists(atPath: configURL.path) {
        print("Existing config found — running setup will overwrite it.\n")
    }

    var numbered: [(number: Int, title: String)] = []
    var n = 1
    print("Available calendars:\n")
    for source in grouped.keys.sorted() {
        print("  \(source)")
        for cal in (grouped[source] ?? []).sorted(by: { $0.title < $1.title }) {
            print(String(format: "    %2d  \(calendarDot(cal))\(cal.title)", n))
            numbered.append((number: n, title: cal.title))
            n += 1
        }
    }

    print("\nChoose calendars to include in recap.")
    print("Enter numbers or names, comma-separated:\n")

    guard let rawInput = promptLine("Recap calendars: ") else {
        print("\nCancelled.")
        return false
    }
    let input = sanitizeLine(rawInput)
    guard !input.isEmpty else {
        print("No calendars entered — nothing written.")
        return false
    }

    let tokens = splitCommaTokens(input)
    let (calNames, unmatched) = matchNumberedTokens(tokens, numbered: numbered, items: all, titleOf: \.title)

    if !unmatched.isEmpty {
        print("Not found: \(unmatched.joined(separator: ", ")) — skipping those")
    }
    guard !calNames.isEmpty else {
        print("No valid calendars — nothing written.")
        return false
    }

    let quoted = calNames.map { "\"\($0)\"" }.joined(separator: ", ")
    print("  → recap = [\(quoted)]\n")

    let toml = "[recap]\ncalendars = [\(quoted)]\n"
    let configDir = configURL.deletingLastPathComponent()
    do {
        try writeConfigFile(toml, to: configURL, configDir: configDir)
        print("Config saved.")
        return true
    } catch {
        fail("Could not write config: \(error.localizedDescription)")
    }
}
