// RemoteCalendarStoreSpec.swift
//
// Tests for CalendarLib RemoteCalendarStore, wired to dispatchCalendarRequest and a
// SpyCalendarStore through a loopback transport — proving both sides agree on every store
// method, with no XPC involved.

import CalendarLib
import Foundation
import GetClearKit
import Testing

private func remote(_ spy: SpyCalendarStore) -> RemoteCalendarStore {
    RemoteCalendarStore(transport: { await dispatchCalendarRequest($0.request, to: spy) }, appVersion: "1.4.0")
}

private let range = DateInterval(start: Date(timeIntervalSince1970: 1_790_000_000), duration: 86400)

@Suite("RemoteCalendarStore")
struct RemoteCalendarStoreTests {
    @Test("fetchCalendars returns the helper store's calendars")
    func fetchCalendars() async throws {
        #expect(try await remote(SpyCalendarStore()).fetchCalendars() == [workCal, personalCal])
    }

    @Test("fetchEvents returns the helper store's events")
    func fetchEventsResult() async throws {
        let spy = SpyCalendarStore()
        spy.events = [makeEvent(title: "All Hands")]
        #expect(try await remote(spy).fetchEvents(in: range, calendarIdentifiers: nil) == [makeEvent(title: "All Hands")])
    }

    @Test("fetchEvents passes the range and calendar filter through to the helper store")
    func fetchEventsArguments() async throws {
        let spy = SpyCalendarStore()
        _ = try await remote(spy).fetchEvents(in: range, calendarIdentifiers: ["id-work"])
        #expect(spy.eventQueries.map { "\($0.range == range) \($0.calendarIdentifiers ?? [])" } == ["true [\"id-work\"]"])
    }

    @Test("add sends the event and returns what the helper store saved")
    func add() async throws {
        let event = makeEvent(title: "Dentist")
        #expect(try await remote(SpyCalendarStore()).add(event) == event)
    }

    @Test("remove delivers the identifier to the helper store")
    func remove() async throws {
        let spy = SpyCalendarStore()
        try await remote(spy).remove(identifier: "e-1")
        #expect(spy.removedIds == ["e-1"])
    }

    @Test("a title that matches nothing throws the same typed not-found as a local store")
    func notFoundIsTyped() async {
        await #expect(throws: CalendarStoreError.notFound("Dentist")) {
            _ = try await remote(SpyCalendarStore()).resolve(title: "Dentist", in: range, calendarIdentifiers: nil)
        }
    }
}
