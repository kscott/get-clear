// CalendarDispatchSpec.swift
//
// Tests for CalendarLib dispatchCalendarRequest — how the helper side answers failures.
// Successful requests are covered end to end in RemoteCalendarStoreSpec.

import CalendarLib
import Foundation
import GetClearKit
import Testing

private struct EventKitLikeError: LocalizedError {
    var errorDescription: String? {
        "Event not found: e-1"
    }
}

/// A store whose every method throws the given error.
private struct FailingStore: CalendarStore {
    let error: Error

    func fetchCalendars() async throws -> [CalendarItem] {
        throw error
    }

    func fetchEvents(in _: DateInterval, calendarIdentifiers _: [String]?) async throws -> [EventItem] {
        throw error
    }

    func add(_: EventItem) async throws -> EventItem {
        throw error
    }

    func remove(identifier _: String) async throws {
        throw error
    }
}

private func reply(to request: CalendarHelperRequest, throwing error: Error) async throws -> HelperReply {
    try await dispatchCalendarRequest(HelperCoding.encode(request), to: FailingStore(error: error))
}

@Suite("dispatchCalendarRequest failures")
struct CalendarDispatchTests {
    @Test("a CalendarStoreError is answered as a typed tool error")
    func typedError() async throws {
        let expected = try HelperReply.failure(.toolError(HelperCoding.encode(CalendarStoreError.noDefaultCalendar)))
        #expect(try await reply(to: .fetchCalendars, throwing: CalendarStoreError.noDefaultCalendar) == expected)
    }

    @Test("any other error is answered with its exact description")
    func otherError() async throws {
        #expect(try await reply(to: .remove(identifier: "e-1"), throwing: EventKitLikeError())
            == .failure(.storeError(message: "Event not found: e-1")))
    }

    @Test("a request that isn't a calendar request is answered as a bad request")
    func badRequest() async {
        let answer = await dispatchCalendarRequest(Data("{\"nope\":{}}".utf8), to: SpyCalendarStore())
        #expect(answer.isBadRequest)
    }
}

private extension HelperReply {
    var isBadRequest: Bool {
        if case .failure(.badRequest) = self { return true }
        return false
    }
}
