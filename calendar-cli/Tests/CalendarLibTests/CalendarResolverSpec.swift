// CalendarResolverSpec.swift
// Tests for CalendarLib CalendarResolver — subset filter resolution to calendar identifiers.

import CalendarLib
import Foundation
import Testing

private let calendars: [CalendarItem] = [
    CalendarItem(identifier: "id-work", title: "Work"),
    CalendarItem(identifier: "id-meetings", title: "Meetings"),
    CalendarItem(identifier: "id-home", title: "Home"),
    CalendarItem(identifier: "id-family", title: "Family")
]

private let config = parseConfig("""
[subsets]
work     = ["Work", "Meetings"]
personal = ["Home", "Family"]
""")

@Suite("resolveCalendarIdentifiers")
struct CalendarResolverTests {
    @Suite("nil filter — no subset specified")
    struct NilFilter {
        @Test("returns nil")
        func returnsNil() {
            let ids = resolveCalendarIdentifiers(filter: nil, calendars: calendars, config: config)
            #expect(ids == nil)
        }
    }

    @Suite("known subset filter")
    struct KnownSubsetFilter {
        @Test("returns only identifiers matching the 'work' subset")
        func workSubsetCount() {
            let ids = resolveCalendarIdentifiers(filter: "work", calendars: calendars, config: config)
            #expect(ids?.count == 2)
        }

        @Test("work subset includes Work identifier")
        func workSubsetIncludesWork() {
            let ids = resolveCalendarIdentifiers(filter: "work", calendars: calendars, config: config)
            #expect(ids?.contains("id-work") == true)
        }

        @Test("work subset includes Meetings identifier")
        func workSubsetIncludesMeetings() {
            let ids = resolveCalendarIdentifiers(filter: "work", calendars: calendars, config: config)
            #expect(ids?.contains("id-meetings") == true)
        }

        @Test("work subset excludes Home identifier")
        func workSubsetExcludesHome() {
            let ids = resolveCalendarIdentifiers(filter: "work", calendars: calendars, config: config)
            #expect(ids?.contains("id-home") != true)
        }

        @Test("personal subset includes Home identifier")
        func personalSubsetIncludesHome() {
            let ids = resolveCalendarIdentifiers(filter: "personal", calendars: calendars, config: config)
            #expect(ids?.contains("id-home") == true)
        }

        @Test("personal subset includes Family identifier")
        func personalSubsetIncludesFamily() {
            let ids = resolveCalendarIdentifiers(filter: "personal", calendars: calendars, config: config)
            #expect(ids?.contains("id-family") == true)
        }

        @Test("personal subset excludes work calendars")
        func personalSubsetExcludesWork() {
            let ids = resolveCalendarIdentifiers(filter: "personal", calendars: calendars, config: config)
            #expect(ids?.contains("id-work") != true)
        }
    }

    @Suite("case sensitivity")
    struct CaseSensitivity {
        @Test("uppercase filter returns the same identifiers as lowercase")
        func uppercaseMatchesLowercase() {
            let lower = resolveCalendarIdentifiers(filter: "work", calendars: calendars, config: config)
            let upper = resolveCalendarIdentifiers(filter: "WORK", calendars: calendars, config: config)
            #expect(upper == lower)
        }

        @Test("mixed-case filter returns the same identifiers as lowercase")
        func mixedCaseMatchesLowercase() {
            let lower = resolveCalendarIdentifiers(filter: "work", calendars: calendars, config: config)
            let mixed = resolveCalendarIdentifiers(filter: "Work", calendars: calendars, config: config)
            #expect(mixed == lower)
        }
    }

    @Suite("unknown filter")
    struct UnknownFilter {
        @Test("returns empty array for an unrecognized filter")
        func emptyForUnrecognized() {
            let ids = resolveCalendarIdentifiers(filter: "unknown", calendars: calendars, config: config)
            #expect(ids?.isEmpty == true)
        }
    }

    @Suite("empty calendars")
    struct EmptyCalendars {
        @Test("returns empty array when no calendars are provided")
        func emptyWhenNoCalendars() {
            let ids = resolveCalendarIdentifiers(filter: "work", calendars: [], config: config)
            #expect(ids?.isEmpty == true)
        }
    }

    @Suite("subset names missing from calendars")
    struct SubsetNamesMissing {
        @Test("returns one result when only one config calendar is present")
        func oneResultWhenPartial() {
            let partial = [CalendarItem(identifier: "id-work", title: "Work")]
            let ids = resolveCalendarIdentifiers(filter: "work", calendars: partial, config: config)
            #expect(ids?.count == 1)
        }

        @Test("includes the matched identifier when others in the subset are absent")
        func includesMatchedWhenOthersAbsent() {
            let partial = [CalendarItem(identifier: "id-work", title: "Work")]
            let ids = resolveCalendarIdentifiers(filter: "work", calendars: partial, config: config)
            #expect(ids?.contains("id-work") == true)
        }
    }
}
