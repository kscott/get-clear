// CalendarResolverSpec.swift
// Tests for CalendarLib CalendarResolver — subset filter resolution to calendar identifiers.

import CalendarLib
import Foundation
import Nimble
import Quick

final class CalendarResolverSpec: QuickSpec {
    override class func spec() {
        let calendars: [CalendarItem] = [
            CalendarItem(identifier: "id-work", title: "Work"),
            CalendarItem(identifier: "id-meetings", title: "Meetings"),
            CalendarItem(identifier: "id-home", title: "Home"),
            CalendarItem(identifier: "id-family", title: "Family")
        ]

        let config = parseConfig("""
        [subsets]
        work     = ["Work", "Meetings"]
        personal = ["Home", "Family"]
        """)

        describe("resolveCalendarIdentifiers") {
            context("nil filter — no subset specified") {
                it("returns nil") {
                    let ids = resolveCalendarIdentifiers(filter: nil, calendars: calendars, config: config)
                    expect(ids).to(beNil())
                }
            }

            context("known subset filter") {
                it("returns only identifiers matching the 'work' subset") {
                    let ids = resolveCalendarIdentifiers(filter: "work", calendars: calendars, config: config)
                    expect(ids?.count) == 2
                }
                it("work subset includes Work identifier") {
                    let ids = resolveCalendarIdentifiers(filter: "work", calendars: calendars, config: config)
                    expect(ids).to(contain("id-work"))
                }
                it("work subset includes Meetings identifier") {
                    let ids = resolveCalendarIdentifiers(filter: "work", calendars: calendars, config: config)
                    expect(ids).to(contain("id-meetings"))
                }
                it("work subset excludes Home identifier") {
                    let ids = resolveCalendarIdentifiers(filter: "work", calendars: calendars, config: config)
                    expect(ids).toNot(contain("id-home"))
                }
                it("personal subset includes Home identifier") {
                    let ids = resolveCalendarIdentifiers(filter: "personal", calendars: calendars, config: config)
                    expect(ids).to(contain("id-home"))
                }
                it("personal subset includes Family identifier") {
                    let ids = resolveCalendarIdentifiers(filter: "personal", calendars: calendars, config: config)
                    expect(ids).to(contain("id-family"))
                }
                it("personal subset excludes work calendars") {
                    let ids = resolveCalendarIdentifiers(filter: "personal", calendars: calendars, config: config)
                    expect(ids).toNot(contain("id-work"))
                }
            }

            context("case sensitivity") {
                it("uppercase filter returns the same identifiers as lowercase") {
                    let lower = resolveCalendarIdentifiers(filter: "work", calendars: calendars, config: config)
                    let upper = resolveCalendarIdentifiers(filter: "WORK", calendars: calendars, config: config)
                    expect(upper) == lower
                }
                it("mixed-case filter returns the same identifiers as lowercase") {
                    let lower = resolveCalendarIdentifiers(filter: "work", calendars: calendars, config: config)
                    let mixed = resolveCalendarIdentifiers(filter: "Work", calendars: calendars, config: config)
                    expect(mixed) == lower
                }
            }

            context("unknown filter") {
                it("returns empty array for an unrecognized filter") {
                    let ids = resolveCalendarIdentifiers(filter: "unknown", calendars: calendars, config: config)
                    expect(ids).to(beEmpty())
                }
            }

            context("empty calendars") {
                it("returns empty array when no calendars are provided") {
                    let ids = resolveCalendarIdentifiers(filter: "work", calendars: [], config: config)
                    expect(ids).to(beEmpty())
                }
            }

            context("subset names missing from calendars") {
                it("returns one result when only one config calendar is present") {
                    let partial = [CalendarItem(identifier: "id-work", title: "Work")]
                    let ids = resolveCalendarIdentifiers(filter: "work", calendars: partial, config: config)
                    expect(ids?.count) == 1
                }
                it("includes the matched identifier when others in the subset are absent") {
                    let partial = [CalendarItem(identifier: "id-work", title: "Work")]
                    let ids = resolveCalendarIdentifiers(filter: "work", calendars: partial, config: config)
                    expect(ids).to(contain("id-work"))
                }
            }
        }
    }
}
