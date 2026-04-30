// SetupHandlerSpec.swift
// Tests for the pure helper functions extracted from SetupHandler.
// handleSetup itself is not tested (interactive I/O).

import CalendarLib
import Foundation
import Nimble
import Quick

final class CalendarSetupHandlerSpec: QuickSpec {
    override class func spec() {
        let cals = [
            CalendarItem(identifier: "id-work", title: "Work", source: "iCloud"),
            CalendarItem(identifier: "id-meetings", title: "Meetings", source: "iCloud"),
            CalendarItem(identifier: "id-home", title: "Home", source: "Personal")
        ]

        // MARK: - numberCalendars

        describe("numberCalendars") {
            it("assigns sequential numbers starting at 1") {
                let numbered = numberCalendars(cals)
                expect(numbered.first?.number) == 1
            }
            it("numbers match the count of input calendars") {
                let numbered = numberCalendars(cals)
                expect(numbered.count) == cals.count
            }
            it("sorts by source then title") {
                let numbered = numberCalendars(cals)
                // "Personal" < "iCloud" in ASCII (uppercase P < lowercase i)
                expect(numbered[0].title) == "Home"
                expect(numbered[1].title) == "Meetings"
                expect(numbered[2].title) == "Work"
            }
        }

        // MARK: - parseCalendarTokens

        describe("parseCalendarTokens") {
            let numbered = [(number: 1, title: "Meetings"),
                            (number: 2, title: "Work"),
                            (number: 3, title: "Home")]

            context("numeric tokens") {
                it("matches a calendar by its number") {
                    let (matched, _) = parseCalendarTokens(tokens: ["1"], numbered: numbered, all: cals)
                    expect(matched) == ["Meetings"]
                }
                it("matches multiple calendars by number") {
                    let (matched, _) = parseCalendarTokens(tokens: ["1", "2"], numbered: numbered, all: cals)
                    expect(matched) == ["Meetings", "Work"]
                }
            }

            context("name tokens") {
                it("matches a calendar by exact name (case-insensitive)") {
                    let (matched, _) = parseCalendarTokens(tokens: ["work"], numbered: numbered, all: cals)
                    expect(matched) == ["Work"]
                }
                it("matches an uppercase name token") {
                    let (matched, _) = parseCalendarTokens(tokens: ["WORK"], numbered: numbered, all: cals)
                    expect(matched) == ["Work"]
                }
            }

            context("unmatched tokens") {
                it("records unmatched tokens") {
                    let (_, unmatched) = parseCalendarTokens(tokens: ["999", "NotACal"], numbered: numbered, all: cals)
                    expect(unmatched).to(contain("999"))
                    expect(unmatched).to(contain("NotACal"))
                }
                it("does not include unmatched tokens in matched list") {
                    let (matched, _) = parseCalendarTokens(tokens: ["NotACal"], numbered: numbered, all: cals)
                    expect(matched).to(beEmpty())
                }
            }

            context("mixed tokens") {
                it("handles a mix of valid numbers and names") {
                    let (matched, unmatched) = parseCalendarTokens(tokens: ["1", "work", "oops"], numbered: numbered, all: cals)
                    expect(matched).to(contain("Meetings"))
                    expect(matched).to(contain("Work"))
                    expect(unmatched) == ["oops"]
                }
            }
        }

        // MARK: - buildSubsetTOML

        describe("buildSubsetTOML") {
            it("produces a [subsets] header") {
                let toml = buildSubsetTOML(subsets: [("work", ["Work", "Meetings"])])
                expect(toml).to(beginWith("[subsets]"))
            }
            it("quotes each calendar name") {
                let toml = buildSubsetTOML(subsets: [("work", ["Work", "Meetings"])])
                expect(toml).to(contain("\"Work\""))
                expect(toml).to(contain("\"Meetings\""))
            }
            it("writes one line per subset") {
                let toml = buildSubsetTOML(subsets: [("work", ["Work"]), ("personal", ["Home"])])
                let lines = toml.components(separatedBy: "\n").filter { $0.contains("=") }
                expect(lines.count) == 2
            }
            it("produces a parseable config for a round-trip") {
                let toml = buildSubsetTOML(subsets: [("work", ["Work", "Meetings"])])
                let config = parseConfig(toml)
                expect(config.subsets["work"]) == ["Work", "Meetings"]
            }
        }
    }
}
