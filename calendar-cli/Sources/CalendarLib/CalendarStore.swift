// CalendarStore.swift

import Foundation

public enum CalendarStoreError: Error, Equatable {
    case notFound(String)
    case ambiguous([EventItem])
    case noDefaultCalendar
}

public protocol CalendarStore {
    func fetchCalendars() async throws -> [CalendarItem]
    func fetchEvents(in range: DateInterval, calendarIdentifiers: [String]?) async throws -> [EventItem]
    func add(_ item: EventItem) async throws -> EventItem
    func remove(identifier: String) async throws
}

public extension CalendarStore {
    func resolve(title: String, in range: DateInterval, calendarIdentifiers: [String]?) async throws -> EventItem {
        let events = try await fetchEvents(in: range, calendarIdentifiers: calendarIdentifiers)
        let lower  = title.lowercased()
        let matches = events.filter { e in
            e.title.caseInsensitiveCompare(title) == .orderedSame || e.title.lowercased().contains(lower)
        }
        switch matches.count {
        case 0:  throw CalendarStoreError.notFound(title)
        case 1:  return matches[0]
        default: throw CalendarStoreError.ambiguous(matches)
        }
    }
}
