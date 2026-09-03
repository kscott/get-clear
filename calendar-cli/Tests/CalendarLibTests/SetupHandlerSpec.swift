// SetupHandlerSpec.swift
// Tests for the pure helper functions extracted from SetupHandler.
// handleSetup itself is not unit tested — it's thin glue around these pieces
// (readLine/print/signal(SIGINT) are process-level, not unit-testable).

import CalendarLib
import Foundation
import Testing

private let cals = [
    CalendarItem(identifier: "id-work", title: "Work", source: "iCloud"),
    CalendarItem(identifier: "id-meetings", title: "Meetings", source: "iCloud"),
    CalendarItem(identifier: "id-home", title: "Home", source: "Personal")
]

// MARK: - numberCalendars

@Suite("numberCalendars")
struct NumberCalendarsTests {
    @Test("assigns sequential numbers starting at 1")
    func sequentialFromOne() {
        let numbered = numberCalendars(cals)
        #expect(numbered.first?.number == 1)
    }

    @Test("numbers match the count of input calendars")
    func countMatches() {
        let numbered = numberCalendars(cals)
        #expect(numbered.count == cals.count)
    }

    @Test("sorts by source then title")
    func sortsBySourceThenTitle() {
        let numbered = numberCalendars(cals)
        // "Personal" < "iCloud" in ASCII (uppercase P < lowercase i)
        #expect(numbered[0].title == "Home")
        #expect(numbered[1].title == "Meetings")
        #expect(numbered[2].title == "Work")
    }
}

/// Token-matching (numeric or name) now lives in GetClearKit.matchNumberedTokens, tested in
/// Tests/GetClearKitTests/SetupKitSpec.swift. This fixture is still used by setupCalendarOutcome
/// tests below, which cover the calendar-specific integration.
private let numbered = [(number: 1, title: "Meetings"),
                        (number: 2, title: "Work"),
                        (number: 3, title: "Home")]

// MARK: - buildSubsetTOML

@Suite("buildSubsetTOML")
struct BuildSubsetTOMLTests {
    @Test("produces a [subsets] header")
    func producesHeader() {
        let toml = buildSubsetTOML(subsets: [("work", ["Work", "Meetings"])])
        #expect(toml.hasPrefix("[subsets]"))
    }

    @Test("quotes each calendar name")
    func quotesCalendarNames() {
        let toml = buildSubsetTOML(subsets: [("work", ["Work", "Meetings"])])
        #expect(toml.contains("\"Work\""))
        #expect(toml.contains("\"Meetings\""))
    }

    @Test("writes one line per subset")
    func oneLinePerSubset() {
        let toml = buildSubsetTOML(subsets: [("work", ["Work"]), ("personal", ["Home"])])
        let lines = toml.components(separatedBy: "\n").filter { $0.contains("=") }
        #expect(lines.count == 2)
    }

    @Test("produces a parseable config for a round-trip")
    func roundTrips() {
        let toml = buildSubsetTOML(subsets: [("work", ["Work", "Meetings"])])
        let config = parseConfig(toml)
        #expect(config.subsets["work"] == ["Work", "Meetings"])
    }
}

// MARK: - formatAvailableCalendars

@Suite("formatAvailableCalendars")
struct FormatAvailableCalendarsTests {
    @Test("starts with the 'Available calendars' header")
    func startsWithHeader() {
        #expect(formatAvailableCalendars(cals).hasPrefix("Available calendars:"))
    }

    @Test("contains every calendar title")
    func containsEveryTitle() {
        let out = formatAvailableCalendars(cals)
        #expect(out.contains("Work"))
        #expect(out.contains("Meetings"))
        #expect(out.contains("Home"))
    }

    @Test("groups calendars under their source heading")
    func groupsUnderSourceHeading() {
        let out = formatAvailableCalendars(cals)
        #expect(out.contains("iCloud"))
        #expect(out.contains("Personal"))
    }

    @Test("numbers calendars sequentially starting at 1 across all groups")
    func numbersSequentially() {
        let out = formatAvailableCalendars(cals)
        #expect(out.contains(" 1  "))
        #expect(out.contains(" 2  "))
        #expect(out.contains(" 3  "))
    }

    @Test("returns just the header for no calendars")
    func emptyForNoCalendars() {
        #expect(formatAvailableCalendars([]) == "Available calendars:\n")
    }
}

// MARK: - formatUnmatched

@Suite("formatUnmatched")
struct FormatUnmatchedTests {
    @Test("returns nil for no unmatched tokens")
    func nilForEmpty() {
        #expect(formatUnmatched([]) == nil)
    }

    @Test("names a single unmatched token")
    func namesSingleToken() {
        #expect(formatUnmatched(["bogus"]) == "  Not found: bogus — skipping those")
    }

    @Test("joins multiple unmatched tokens with a comma")
    func joinsMultipleTokens() {
        #expect(formatUnmatched(["bogus", "nope"]) == "  Not found: bogus, nope — skipping those")
    }
}

// MARK: - setupNameOutcome

@Suite("setupNameOutcome")
struct SetupNameOutcomeTests {
    @Test("returns cancelled for nil input (EOF)")
    func cancelledOnNil() {
        #expect(setupNameOutcome(nil) == .cancelled)
    }

    @Test("returns finished for empty input")
    func finishedOnEmpty() {
        #expect(setupNameOutcome("") == .finished)
    }

    @Test("returns finished for whitespace-only input")
    func finishedOnWhitespace() {
        #expect(setupNameOutcome("   ") == .finished)
    }

    @Test("returns proceed with the lowercased name")
    func proceedsWithLowercasedName() {
        #expect(setupNameOutcome("Work") == .proceed(subsetName: "work"))
    }

    @Test("strips control characters via sanitizeLine")
    func stripsControlCharacters() {
        #expect(setupNameOutcome("wo\u{07}rk") == .proceed(subsetName: "work"))
    }
}

// MARK: - setupCalendarOutcome

@Suite("setupCalendarOutcome")
struct SetupCalendarOutcomeTests {
    @Test("returns cancelled for nil input (EOF)")
    func cancelledOnNil() {
        #expect(setupCalendarOutcome(nil, numbered: numbered, all: cals) == .cancelled)
    }

    @Test("returns emptyInput for whitespace-only input")
    func emptyInputOnWhitespace() {
        #expect(setupCalendarOutcome("   ", numbered: numbered, all: cals) == .emptyInput)
    }

    @Test("returns noValidCalendars when no tokens match")
    func noValidCalendarsWhenNoneMatch() {
        #expect(
            setupCalendarOutcome("nope", numbered: numbered, all: cals)
                == .noValidCalendars(unmatched: ["nope"])
        )
    }

    @Test("returns subsetAdded with a calendar matched by number")
    func subsetAddedByNumber() {
        #expect(
            setupCalendarOutcome("1", numbered: numbered, all: cals)
                == .subsetAdded(calendars: ["Meetings"], unmatched: [])
        )
    }

    @Test("returns subsetAdded with a calendar matched by name")
    func subsetAddedByName() {
        #expect(
            setupCalendarOutcome("Work", numbered: numbered, all: cals)
                == .subsetAdded(calendars: ["Work"], unmatched: [])
        )
    }

    @Test("returns subsetAdded with unmatched tokens listed alongside matched ones")
    func subsetAddedWithPartialMatch() {
        #expect(
            setupCalendarOutcome("Work, bogus", numbered: numbered, all: cals)
                == .subsetAdded(calendars: ["Work"], unmatched: ["bogus"])
        )
    }
}

// MARK: - writeSetupConfig

@Suite("writeSetupConfig")
struct WriteSetupConfigTests {
    /// A fresh, unique temp directory per test — never the real ~/.config/calendar-cli/config.toml.
    private func tempConfigURL() -> (configURL: URL, configDir: URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (dir.appendingPathComponent("config.toml"), dir)
    }

    @Test("creates the config directory and writes the file")
    func createsDirectoryAndWritesFile() throws {
        let (configURL, configDir) = tempConfigURL()
        defer { try? FileManager.default.removeItem(at: configDir) }
        _ = try writeSetupConfig(subsets: [("work", ["Work"])], configURL: configURL, configDir: configDir)
        #expect(FileManager.default.fileExists(atPath: configURL.path))
    }

    @Test("writes valid subset TOML that round-trips through parseConfig")
    func writesValidTOML() throws {
        let (configURL, configDir) = tempConfigURL()
        defer { try? FileManager.default.removeItem(at: configDir) }
        _ = try writeSetupConfig(subsets: [("work", ["Work", "Meetings"])], configURL: configURL, configDir: configDir)
        let content = try String(contentsOf: configURL, encoding: .utf8)
        #expect(parseConfig(content).subsets["work"] == ["Work", "Meetings"])
    }

    @Test("includes a 'Try it' hint naming the first subset")
    func includesTryItHint() throws {
        let (configURL, configDir) = tempConfigURL()
        defer { try? FileManager.default.removeItem(at: configDir) }
        let result = try writeSetupConfig(subsets: [("work", ["Work"])], configURL: configURL, configDir: configDir)
        #expect(result.contains("Try it: calendar work today"))
    }

    @Test("includes the written path in the confirmation message")
    func includesPathInMessage() throws {
        let (configURL, configDir) = tempConfigURL()
        defer { try? FileManager.default.removeItem(at: configDir) }
        let result = try writeSetupConfig(subsets: [("work", ["Work"])], configURL: configURL, configDir: configDir)
        #expect(result.contains(configURL.path))
    }
}
