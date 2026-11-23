// RemoteCalendarStore.swift
//
// A CalendarStore whose every method is a request to the Get Clear helper, which holds
// the Calendars permission (spec 018). Pure: the transport is injected.

import Foundation
import GetClearKit

public struct RemoteCalendarStore: CalendarStore {
    private let caller: HelperCaller

    public init(transport: @escaping HelperTransport, appVersion: String) {
        caller = HelperCaller(
            tool: .calendar,
            appVersion: appVersion,
            transport: transport,
            decodeToolError: { try? HelperCoding.decode(CalendarStoreError.self, from: $0) }
        )
    }

    public func fetchCalendars() async throws -> [CalendarItem] {
        try await caller.call(CalendarHelperRequest.fetchCalendars)
    }

    public func fetchEvents(in range: DateInterval, calendarIdentifiers: [String]?) async throws -> [EventItem] {
        try await caller.call(CalendarHelperRequest.fetchEvents(range: range, calendarIdentifiers: calendarIdentifiers))
    }

    public func add(_ item: EventItem) async throws -> EventItem {
        try await caller.call(CalendarHelperRequest.add(item))
    }

    public func remove(identifier: String) async throws {
        try await caller.perform(CalendarHelperRequest.remove(identifier: identifier))
    }
}
