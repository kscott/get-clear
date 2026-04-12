// AddCommand.swift

import Foundation
import EventKit
import CalendarLib
import GetClearKit

func handleAdd(args: [String], store: EKEventStore, calFilter: String?,
               config: CalendarConfig, semaphore: DispatchSemaphore) {
    guard args.count > 1 else { fail("provide an event title") }
    let title  = args[1]
    let dStr   = Array(args.dropFirst(2)).joined(separator: " ")
    guard let edt = parseEventDateTime(dStr.isEmpty ? "today" : dStr) else {
        fail("unrecognised date/time: \(dStr)")
    }
    let cals = resolveCalendars(calFilter, store: store, config: config)
    guard let targetCal = cals.first ?? store.defaultCalendarForNewEvents else {
        fail("no calendar available")
    }
    let endDate  = edt.end ?? Calendar.current.date(byAdding: .hour, value: 1, to: edt.start)!
    let ev       = EKEvent(eventStore: store)
    ev.title     = title; ev.calendar = targetCal
    ev.isAllDay  = edt.isAllDay; ev.startDate = edt.start; ev.endDate = endDate
    do {
        try store.save(ev, span: .thisEvent, commit: true)
        try? ActivityLog.write(tool: "calendar", cmd: "add", desc: title, container: targetCal.title)
        let detail = edt.isAllDay ? "all day" : "\(formatEventTime(edt.start)) – \(formatEventTime(endDate))"
        print("Added: \(title) · \(shortDateFormatter.string(from: edt.start)) \(detail) (\(targetCal.title))")
    } catch { fail("Could not save event: \(error.localizedDescription)") }
    semaphore.signal()
}
