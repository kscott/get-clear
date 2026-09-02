// SetupHandlerSpec.swift
// Tests for the pure helper functions extracted from SetupHandler.
// handleSetup itself is not tested (interactive I/O).

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

// MARK: - parseCalendarTokens

private let numbered = [(number: 1, title: "Meetings"),
                        (number: 2, title: "Work"),
                        (number: 3, title: "Home")]

@Suite("parseCalendarTokens")
struct ParseCalendarTokensTests {
    @Suite("numeric tokens")
    struct NumericTokens {
        @Test("matches a calendar by its number")
        func matchesByNumber() {
            let (matched, _) = parseCalendarTokens(tokens: ["1"], numbered: numbered, all: cals)
            #expect(matched == ["Meetings"])
        }

        @Test("matches multiple calendars by number")
        func matchesMultipleByNumber() {
            let (matched, _) = parseCalendarTokens(tokens: ["1", "2"], numbered: numbered, all: cals)
            #expect(matched == ["Meetings", "Work"])
        }
    }

    @Suite("name tokens")
    struct NameTokens {
        @Test("matches a calendar by exact name (case-insensitive)")
        func matchesByExactName() {
            let (matched, _) = parseCalendarTokens(tokens: ["work"], numbered: numbered, all: cals)
            #expect(matched == ["Work"])
        }

        @Test("matches an uppercase name token")
        func matchesUppercaseName() {
            let (matched, _) = parseCalendarTokens(tokens: ["WORK"], numbered: numbered, all: cals)
            #expect(matched == ["Work"])
        }
    }

    @Suite("unmatched tokens")
    struct UnmatchedTokens {
        @Test("records unmatched tokens")
        func recordsUnmatched() {
            let (_, unmatched) = parseCalendarTokens(tokens: ["999", "NotACal"], numbered: numbered, all: cals)
            #expect(unmatched.contains("999"))
            #expect(unmatched.contains("NotACal"))
        }

        @Test("does not include unmatched tokens in matched list")
        func unmatchedNotInMatched() {
            let (matched, _) = parseCalendarTokens(tokens: ["NotACal"], numbered: numbered, all: cals)
            #expect(matched.isEmpty)
        }
    }

    @Suite("mixed tokens")
    struct MixedTokens {
        @Test("handles a mix of valid numbers and names")
        func handlesMix() {
            let (matched, unmatched) = parseCalendarTokens(tokens: ["1", "work", "oops"], numbered: numbered, all: cals)
            #expect(matched.contains("Meetings"))
            #expect(matched.contains("Work"))
            #expect(unmatched == ["oops"])
        }
    }
}

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
