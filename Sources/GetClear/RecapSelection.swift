// RecapSelection.swift
//
// Recap's two choices about calendar data, as pure functions over CalendarLib value types:
// which calendars a recap covers, and which of their events have already happened.

import CalendarLib
import Foundation

/// Identifiers of the calendars a recap covers, or nil for "all calendars".
/// With no names configured, that's the user's own calendars (no subscriptions, no Birthdays).
/// A name list that matches nothing also yields nil, so recap never silently shows no calendars.
func recapCalendarIDs(names: [String]?, from calendars: [CalendarItem]) -> [String]? {
    let chosen = if let names {
        calendars.filter { names.contains($0.title) }
    } else {
        calendars.filter(\.kind.isUserOwned)
    }
    return chosen.isEmpty ? nil : chosen.map(\.identifier)
}

/// Events that have already happened (FR-015): a timed event once it has ended; an all-day event
/// when its day falls inside the range.
func pastEvents(_ events: [EventItem], in range: ClosedRange<Date>, now: Date, calendar: Calendar) -> [EventItem] {
    events.filter { event in
        if event.isAllDay {
            let day = calendar.startOfDay(for: event.startDate)
            return day >= calendar.startOfDay(for: range.lowerBound) && day <= calendar.startOfDay(for: range.upperBound)
        }
        return (event.endDate ?? event.startDate) <= now
    }
}
