// EventFetcher.swift
//
// EventKit store access: calendar resolution, event fetching, and EKEvent conversion.

import Foundation
import EventKit
import CalendarLib
import GetClearKit

/// Extracts an RGB color triple from an EKCalendar's CGColor, or nil when unavailable.
func calendarColor(_ cal: EKCalendar) -> (r: Int, g: Int, b: Int)? {
    guard let cg = cal.cgColor else { return nil }
    let colorSpace = cg.colorSpace?.model
    let components = cg.components ?? []
    if colorSpace == .rgb, components.count >= 3 {
        return (Int(components[0] * 255), Int(components[1] * 255), Int(components[2] * 255))
    } else if colorSpace == .monochrome, components.count >= 1 {
        let w = Int(components[0] * 255)
        return (w, w, w)
    }
    return nil
}

/// Converts an EKEvent to the plain-data EventDisplayData required by CalendarLib formatters.
func displayData(for event: EKEvent) -> EventDisplayData {
    EventDisplayData(
        title:         event.title ?? "(no title)",
        start:         event.startDate,
        end:           event.endDate,
        isAllDay:      event.isAllDay,
        calendarName:  event.calendar.title,
        calendarColor: calendarColor(event.calendar),
        location:      event.location
    )
}

/// Resolves a filter string to matching EKCalendar objects using the loaded config.
func resolveCalendars(_ filter: String?, store: EKEventStore, config: CalendarConfig) -> [EKCalendar] {
    let all     = store.calendars(for: .event)
    let entries = all.map { CalendarEntry(name: $0.title, identifier: $0.calendarIdentifier) }
    let ids     = resolveCalendarIdentifiers(filter: filter, entries: entries, config: config)
    if filter != nil && ids.isEmpty { fail("No calendars matched filter '\(filter!)'") }
    return all.filter { ids.contains($0.calendarIdentifier) }
}

/// Fetches and deduplicates events from the store for the given range and calendars.
func fetchEvents(in range: ParsedRange, calendars: [EKCalendar], store: EKEventStore) -> [EKEvent] {
    let predicate = store.predicateForEvents(withStart: range.start,
                                             end: range.end,
                                             calendars: calendars.isEmpty ? nil : calendars)
    let sorted = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    var seen = Set<String>()
    return sorted.filter { seen.insert($0.eventIdentifier).inserted }
}
