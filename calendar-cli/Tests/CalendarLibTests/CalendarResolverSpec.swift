// CalendarResolverSpec.swift
//
// Tests for CalendarLib CalendarResolver — subset filter resolution to calendar identifiers.

import Quick
import Nimble
import Foundation
import CalendarLib

final class CalendarResolverSpec: QuickSpec {
    override class func spec() {

        // Sample entries: name and a unique identifier
        let entries: [CalendarEntry] = [
            CalendarEntry(name: "Work",     identifier: "id-work"),
            CalendarEntry(name: "Meetings", identifier: "id-meetings"),
            CalendarEntry(name: "Home",     identifier: "id-home"),
            CalendarEntry(name: "Family",   identifier: "id-family"),
        ]

        let config = parseConfig("""
        [subsets]
        work     = ["Work", "Meetings"]
        personal = ["Home", "Family"]
        """)

        describe("resolveCalendarIdentifiers") {

            context("nil filter — no subset specified") {
                it("returns all identifiers") {
                    let ids = resolveCalendarIdentifiers(filter: nil, entries: entries, config: config)
                    expect(ids.count) == 4
                }
                it("includes the Work identifier") {
                    let ids = resolveCalendarIdentifiers(filter: nil, entries: entries, config: config)
                    expect(ids).to(contain("id-work"))
                }
                it("includes the Meetings identifier") {
                    let ids = resolveCalendarIdentifiers(filter: nil, entries: entries, config: config)
                    expect(ids).to(contain("id-meetings"))
                }
                it("includes the Home identifier") {
                    let ids = resolveCalendarIdentifiers(filter: nil, entries: entries, config: config)
                    expect(ids).to(contain("id-home"))
                }
                it("includes the Family identifier") {
                    let ids = resolveCalendarIdentifiers(filter: nil, entries: entries, config: config)
                    expect(ids).to(contain("id-family"))
                }
            }

            context("known subset filter") {
                it("returns only identifiers matching the 'work' subset") {
                    let ids = resolveCalendarIdentifiers(filter: "work", entries: entries, config: config)
                    expect(ids.count) == 2
                }
                it("work subset includes Work identifier") {
                    let ids = resolveCalendarIdentifiers(filter: "work", entries: entries, config: config)
                    expect(ids).to(contain("id-work"))
                }
                it("work subset includes Meetings identifier") {
                    let ids = resolveCalendarIdentifiers(filter: "work", entries: entries, config: config)
                    expect(ids).to(contain("id-meetings"))
                }
                it("work subset excludes Home identifier") {
                    let ids = resolveCalendarIdentifiers(filter: "work", entries: entries, config: config)
                    expect(ids).toNot(contain("id-home"))
                }
                it("personal subset includes Home identifier") {
                    let ids = resolveCalendarIdentifiers(filter: "personal", entries: entries, config: config)
                    expect(ids).to(contain("id-home"))
                }
                it("personal subset includes Family identifier") {
                    let ids = resolveCalendarIdentifiers(filter: "personal", entries: entries, config: config)
                    expect(ids).to(contain("id-family"))
                }
                it("personal subset excludes work calendars") {
                    let ids = resolveCalendarIdentifiers(filter: "personal", entries: entries, config: config)
                    expect(ids).toNot(contain("id-work"))
                }
            }

            context("case sensitivity") {
                it("uppercase filter returns the same identifiers as lowercase") {
                    let lower = resolveCalendarIdentifiers(filter: "work", entries: entries, config: config)
                    let upper = resolveCalendarIdentifiers(filter: "WORK", entries: entries, config: config)
                    expect(upper) == lower
                }
                it("mixed-case filter returns the same identifiers as lowercase") {
                    let lower = resolveCalendarIdentifiers(filter: "work", entries: entries, config: config)
                    let mixed = resolveCalendarIdentifiers(filter: "Work", entries: entries, config: config)
                    expect(mixed) == lower
                }
            }

            context("unknown filter") {
                it("returns empty array for an unrecognized filter") {
                    let ids = resolveCalendarIdentifiers(filter: "unknown", entries: entries, config: config)
                    expect(ids).to(beEmpty())
                }
            }

            context("empty entries") {
                it("returns empty array when no entries are provided") {
                    let ids = resolveCalendarIdentifiers(filter: "work", entries: [], config: config)
                    expect(ids).to(beEmpty())
                }
            }

            context("subset names missing from entries") {
                it("returns one result when only one config calendar is present in entries") {
                    let partial: [CalendarEntry] = [CalendarEntry(name: "Work", identifier: "id-work")]
                    let ids = resolveCalendarIdentifiers(filter: "work", entries: partial, config: config)
                    expect(ids.count) == 1
                }
                it("includes the matched identifier when others in the subset are absent") {
                    let partial: [CalendarEntry] = [CalendarEntry(name: "Work", identifier: "id-work")]
                    let ids = resolveCalendarIdentifiers(filter: "work", entries: partial, config: config)
                    expect(ids).to(contain("id-work"))
                }
            }
        }
    }
}
