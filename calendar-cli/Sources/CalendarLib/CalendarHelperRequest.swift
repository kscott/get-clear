// CalendarHelperRequest.swift
//
// One case per CalendarStore method: what a command asks the Get Clear helper to do with
// Calendars (spec 018). Adding a store method means adding a case here, in
// RemoteCalendarStore, and in CalendarDispatch.

import Foundation

public enum CalendarHelperRequest: Codable, Equatable, Sendable {
    case fetchCalendars
    case fetchEvents(range: DateInterval, calendarIdentifiers: [String]?)
    case add(EventItem)
    case remove(identifier: String)
}
