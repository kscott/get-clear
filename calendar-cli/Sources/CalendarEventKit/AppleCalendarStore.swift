// AppleCalendarStore.swift
// EventKit implementation of CalendarStore. All EKEventStore access lives in this file.

import CalendarLib
import EventKit
import Foundation
import GetClearKit

enum AppleCalendarStoreError: LocalizedError {
    case accessDenied
    case noDefaultCalendar
    case eventNotFound(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied: "Calendar access denied"
        case .noDefaultCalendar: "No default calendar available"
        case let .eventNotFound(id): "Event not found: \(id)"
        }
    }
}

public final class AppleCalendarStore: CalendarStore {
    private let store: EKEventStore

    private init(_ store: EKEventStore) {
        self.store = store
    }

    public static func authorized() async throws -> AppleCalendarStore {
        let store = EKEventStore()
        guard try await store.requestFullAccessToEvents() else {
            throw AppleCalendarStoreError.accessDenied
        }
        return AppleCalendarStore(store)
    }

    // MARK: - CalendarStore

    public func fetchCalendars() async throws -> [CalendarItem] {
        store.calendars(for: .event).map(CalendarItem.init(_:))
    }

    public func fetchEvents(in range: DateInterval, calendarIdentifiers: [String]?) async throws -> [EventItem] {
        let cals: [EKCalendar]? = if let ids = calendarIdentifiers {
            store.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
        } else {
            nil
        }
        let pred = store.predicateForEvents(withStart: range.start, end: range.end, calendars: cals)
        let sorted = store.events(matching: pred).sorted { $0.startDate < $1.startDate }
        var seen = Set<String>()
        return sorted
            .filter { seen.insert($0.eventIdentifier).inserted }
            .map(EventItem.init(_:))
    }

    public func add(_ item: EventItem) async throws -> EventItem {
        let allCals = store.calendars(for: .event)
        let targetCal: EKCalendar
        if let id = item.calendarIdentifier,
           let cal = allCals.first(where: { $0.calendarIdentifier == id })
        {
            targetCal = cal
        } else if let cal = allCals.first(where: { $0.title == item.calendarTitle }) {
            targetCal = cal
        } else if let def = store.defaultCalendarForNewEvents {
            targetCal = def
        } else {
            throw AppleCalendarStoreError.noDefaultCalendar
        }
        let ev = EKEvent(eventStore: store)
        ev.title = item.title
        ev.calendar = targetCal
        ev.isAllDay = item.isAllDay
        ev.startDate = item.startDate
        ev.endDate = item.endDate ?? Calendar.current.date(byAdding: .hour, value: 1, to: item.startDate) ?? item.startDate.addingTimeInterval(3600)
        ev.location = item.location
        ev.notes = item.notes
        ev.url = item.url
        try store.save(ev, span: .thisEvent, commit: true)
        return EventItem(ev)
    }

    public func remove(identifier: String) async throws {
        guard let ev = store.event(withIdentifier: identifier) else {
            throw AppleCalendarStoreError.eventNotFound(identifier)
        }
        try store.remove(ev, span: .thisEvent, commit: true)
    }
}

// MARK: - Conversion

private extension CalendarItem {
    init(_ cal: EKCalendar) {
        self.init(
            identifier: cal.calendarIdentifier,
            title: cal.title,
            color: hexColor(cal),
            source: cal.source.title,
            isModifiable: cal.allowsContentModifications
        )
    }
}

private extension EventItem {
    init(_ e: EKEvent) {
        self.init(
            identifier: e.eventIdentifier,
            title: e.title ?? "(no title)",
            startDate: e.startDate,
            endDate: e.endDate,
            isAllDay: e.isAllDay,
            calendarTitle: e.calendar.title,
            calendarIdentifier: e.calendar.calendarIdentifier,
            calendarColor: hexColor(e.calendar),
            location: e.location,
            notes: e.notes,
            url: e.url,
            attendees: (e.attendees ?? []).compactMap(AttendeeItem.init(_:))
        )
    }
}

private extension AttendeeItem {
    init?(_ p: EKParticipant) {
        guard let name = p.name else { return nil }
        let status = switch p.participantStatus {
        case .accepted: "accepted"
        case .declined: "declined"
        case .tentative: "tentative"
        default: "invited"
        }
        self.init(name: name, status: status)
    }
}

/// Extracts a 6-character uppercase hex string from an EKCalendar's CGColor.
private func hexColor(_ cal: EKCalendar) -> String? {
    guard let cg = cal.cgColor else { return nil }
    let model = cg.colorSpace?.model
    let components = cg.components ?? []
    let r: Int
    let g: Int
    let b: Int
    if model == .rgb, components.count >= 3 {
        r = Int(components[0] * 255)
        g = Int(components[1] * 255)
        b = Int(components[2] * 255)
    } else if model == .monochrome, components.count >= 1 {
        let w = Int(components[0] * 255)
        r = w
        g = w
        b = w
    } else {
        return nil
    }
    return String(format: "%02X%02X%02X", r, g, b)
}
