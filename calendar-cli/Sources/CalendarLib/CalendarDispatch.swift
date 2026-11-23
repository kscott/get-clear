// CalendarDispatch.swift
//
// The helper side of RemoteCalendarStore: decodes one CalendarHelperRequest, runs it against
// the real store, and answers with the encoded result or error (spec 018). Pure over the
// CalendarStore protocol, so tests run it against a spy.

import Foundation
import GetClearKit

public func dispatchCalendarRequest(_ request: Data, to store: any CalendarStore) async -> HelperReply {
    await HelperResponder.respond(
        to: request,
        as: CalendarHelperRequest.self,
        encodeToolError: { ($0 as? CalendarStoreError).flatMap { try? HelperCoding.encode($0) } },
        handle: { try await run($0, on: store) }
    )
}

private func run(_ request: CalendarHelperRequest, on store: any CalendarStore) async throws -> Data {
    switch request {
    case .fetchCalendars:
        return try await HelperCoding.encode(store.fetchCalendars())
    case let .fetchEvents(range, calendarIdentifiers):
        return try await HelperCoding.encode(store.fetchEvents(in: range, calendarIdentifiers: calendarIdentifiers))
    case let .add(item):
        return try await HelperCoding.encode(store.add(item))
    case let .remove(identifier):
        try await store.remove(identifier: identifier)
        return try HelperCoding.encode(HelperNoResult())
    }
}
