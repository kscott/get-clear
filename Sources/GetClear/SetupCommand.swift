// SetupCommand.swift
// Runs the interactive recap calendar setup flow.

import Foundation
import EventKit
import GetClearKit

/// Presents the calendar picker and writes the recap config.
/// Returns true if config was successfully written, false if cancelled or no valid input.
func runSetup() -> Bool {
    // Install SIGINT handler here rather than at the call site — setup is the only command
    // that blocks on user input, so this is the only place where Ctrl-C needs clean handling.
    signal(SIGINT) { _ in print("\nCancelled."); exit(0) }
    let sem   = DispatchSemaphore(value: 0)
    let store = EKEventStore()
    var configured = false

    store.requestFullAccessToEvents { granted, _ in
        guard granted else { fail("Calendar access required for setup") }

        let all     = store.calendars(for: .event)
        let grouped = Dictionary(grouping: all) { $0.source.title }

        let configURL = getClearConfigURL
        if FileManager.default.fileExists(atPath: configURL.path) {
            print("Existing config found — running setup will overwrite it.\n")
        }

        var numberedCals: [(Int, EKCalendar)] = []
        var n = 1
        print("Available calendars:\n")
        for source in grouped.keys.sorted() {
            print("  \(source)")
            for cal in (grouped[source] ?? []).sorted(by: { $0.title < $1.title }) {
                print(String(format: "    %2d  \(calendarDot(cal))\(cal.title)", n))
                numberedCals.append((n, cal))
                n += 1
            }
        }

        print("\nChoose calendars to include in recap.")
        print("Enter numbers or names, comma-separated:\n")
        print("Recap calendars: ", terminator: "")
        fflush(stdout)

        guard let rawInput = readLine() else { print("\nCancelled."); sem.signal(); return }
        let input = String(rawInput.unicodeScalars.filter { $0.value >= 32 && $0.value < 127 })
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else {
            print("No calendars entered — nothing written.")
            sem.signal()
            return
        }

        let tokens = input.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var calNames: [String] = []
        var unmatched: [String] = []
        for token in tokens {
            if let num = Int(token),
               let match = numberedCals.first(where: { $0.0 == num }) {
                calNames.append(match.1.title)
            } else if let match = all.first(where: {
                $0.title.lowercased() == token.lowercased()
            }) {
                calNames.append(match.title)
            } else {
                unmatched.append(token)
            }
        }

        if !unmatched.isEmpty {
            print("Not found: \(unmatched.joined(separator: ", ")) — skipping those")
        }
        guard !calNames.isEmpty else {
            print("No valid calendars — nothing written.")
            sem.signal()
            return
        }

        let quoted = calNames.map { "\"\($0)\"" }.joined(separator: ", ")
        print("  → recap = [\(quoted)]\n")

        let toml = "[recap]\ncalendars = [\(quoted)]\n"
        let configDir = configURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            try toml.write(to: configURL, atomically: true, encoding: .utf8)
            print("Config saved.")
            configured = true
        } catch {
            fail("Could not write config: \(error.localizedDescription)")
        }
        sem.signal()
    }
    sem.wait()
    return configured
}
