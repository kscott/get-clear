// RemoveCommand.swift

import Foundation
import EventKit
import CalendarLib
import GetClearKit

func handleRemove(args: [String], store: EKEventStore, calFilter: String?,
                  config: CalendarConfig, semaphore: DispatchSemaphore) {
    guard args.count > 1 else { fail("provide an event title") }
    let title    = args[1]
    let rangeStr = args.count > 2 ? Array(args.dropFirst(2)).joined(separator: " ") : nil
    let range    = rangeStr.flatMap { parseRange($0) } ?? parseRange("30d")!
    let lower    = title.lowercased()
    let matches  = fetchEvents(in: range,
                               calendars: resolveCalendars(calFilter, store: store, config: config),
                               store: store)
        .filter { ($0.title ?? "").caseInsensitiveCompare(title) == .orderedSame ||
                  ($0.title ?? "").lowercased().contains(lower) }
    guard !matches.isEmpty else { fail("Not found: \(title)") }
    if matches.count > 1 {
        let df = DateFormatter(); df.dateFormat = "EEE MMM d"
        print("Multiple events match '\(title)':")
        for e in matches {
            print("  \(df.string(from: e.startDate))  \(e.isAllDay ? "all day" : formatEventTime(e.startDate))  \(e.title ?? "")")
        }
        print("Add a date to narrow the search, e.g.: calendar remove \"\(title)\" tomorrow")
        exit(1)
    }
    let ev = matches[0]
    do {
        let calName = ev.calendar.title; let evTitle = ev.title ?? ""
        try store.remove(ev, span: .thisEvent, commit: true)
        try? ActivityLog.write(tool: "calendar", cmd: "remove", desc: evTitle, container: calName)
        let df = DateFormatter(); df.dateFormat = "EEE MMM d"
        print("Removed: \(evTitle) (\(df.string(from: ev.startDate)))")
    } catch { fail("Could not remove event: \(error.localizedDescription)") }
    semaphore.signal()
}
