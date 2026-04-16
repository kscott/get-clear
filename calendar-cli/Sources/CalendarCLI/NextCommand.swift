// NextCommand.swift

import EventKit
import CalendarLib
import GetClearKit

func handleNext(args: [String], store: EKEventStore, calFilter: String?,
                config: CalendarConfig, semaphore: DispatchSemaphore) {
    let n   = args.count > 1 ? (Int(args[1]) ?? 5) : 5
    let now = Date()
    let upcoming = fetchEvents(in: parseRange("90d")!,
                               calendars: resolveCalendars(calFilter, store: store, config: config),
                               store: store)
        .filter { $0.endDate > now }
        .prefix(n)
    if upcoming.isEmpty {
        print("No upcoming events in the next 90 days")
    } else {
        for e in upcoming {
            let lbl  = nextRelativeLabel(for: e.startDate, relativeTo: now)
            let time = e.isAllDay ? "All day  " : formatEventTime(e.startDate)
            var txt  = e.title ?? "(no title)"
            if let loc = e.location, !loc.isEmpty {
                txt += " · " + (loc.components(separatedBy: "\n").first ?? loc)
            }
            print("\(colorDot(calendarColor(e.calendar))) \(lbl)  \(time)   \(txt)")
        }
    }
    semaphore.signal()
}
