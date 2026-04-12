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
                it("includes all known identifiers") {
                    let ids = resolveCalendarIdentifiers(filter: nil, entries: entries, config: config)
                    expect(ids).to(contain("id-work"))
                    expect(ids).to(contain("id-meetings"))
                    expect(ids).to(contain("id-home"))
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
                it("personal subset returns Home and Family identifiers") {
                    let ids = resolveCalendarIdentifiers(filter: "personal", entries: entries, config: config)
                    expect(ids).to(contain("id-home"))
                    expect(ids).to(contain("id-family"))
                }
                it("personal subset excludes work calendars") {
                    let ids = resolveCalendarIdentifiers(filter: "personal", entries: entries, config: config)
                    expect(ids).toNot(contain("id-work"))
                }
            }

            context("case sensitivity") {
                it("filter matching is case-insensitive") {
                    let lower = resolveCalendarIdentifiers(filter: "work",  entries: entries, config: config)
                    let upper = resolveCalendarIdentifiers(filter: "WORK",  entries: entries, config: config)
                    let mixed = resolveCalendarIdentifiers(filter: "Work",  entries: entries, config: config)
                    expect(lower) == upper
                    expect(lower) == mixed
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
                it("skips calendar names in config that are not in the entries list") {
                    let partial: [CalendarEntry] = [CalendarEntry(name: "Work", identifier: "id-work")]
                    let ids = resolveCalendarIdentifiers(filter: "work", entries: partial, config: config)
                    expect(ids.count) == 1
                    expect(ids).to(contain("id-work"))
                }
            }
        }
    }
}
