// TodayCommand.swift

import EventKit
import CalendarLib
import GetClearKit

func handleToday(store: EKEventStore, calFilter: String?,
                 config: CalendarConfig, semaphore: DispatchSemaphore) {
    let range = parseRange("today")!
    let evts  = fetchEvents(in: range, calendars: resolveCalendars(calFilter, store: store, config: config),
                            store: store).map(displayData)
    let hdr   = dayHeaderFormatter.string(from: range.start)
    if evts.isEmpty {
        print("\(hdr)\n  (nothing scheduled)")
    } else {
        printFlat(evts, showHeader: true, header: hdr)
    }
    semaphore.signal()
}
