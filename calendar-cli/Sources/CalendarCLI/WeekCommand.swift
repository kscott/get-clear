// WeekCommand.swift

import EventKit
import CalendarLib
import GetClearKit

func handleWeek(store: EKEventStore, calFilter: String?,
                config: CalendarConfig, semaphore: DispatchSemaphore) {
    let evts = fetchEvents(in: parseRange("week")!,
                           calendars: resolveCalendars(calFilter, store: store, config: config),
                           store: store).map(displayData)
    if evts.isEmpty {
        print("No events this week")
    } else {
        printGrouped(evts, calFilter: calFilter)
    }
    semaphore.signal()
}
