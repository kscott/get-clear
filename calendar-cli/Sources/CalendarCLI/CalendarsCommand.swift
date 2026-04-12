// CalendarsCommand.swift

import EventKit
import CalendarLib

func handleCalendars(store: EKEventStore, semaphore: DispatchSemaphore) {
    let all     = store.calendars(for: .event)
    let grouped = Dictionary(grouping: all) { $0.source.title }
    for source in grouped.keys.sorted() {
        print(source)
        for cal in (grouped[source] ?? []).sorted(by: { $0.title < $1.title }) {
            print("  \(colorDot(calendarColor(cal)))\(cal.title)")
        }
    }
    semaphore.signal()
}
