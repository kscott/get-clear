// AddHandler.swift

import Foundation
import GetClearKit

public func handleAdd(
    args: [String], store: any CalendarStore, calFilter: String?, config: CalendarConfig
) async throws -> String {
    guard args.count > 1 else { throw CalendarHandlerError("provide an event title") }
    let title = args[1]
    let dStr = Array(args.dropFirst(2)).joined(separator: " ")
    guard let edt = parseEventDateTime(dStr.isEmpty ? "today" : dStr) else {
        throw CalendarHandlerError("unrecognised date/time: \(dStr)")
    }
    let allCals = try await store.fetchCalendars()
    let ids = resolveCalendarIdentifiers(filter: calFilter, calendars: allCals, config: config)
    if calFilter != nil && (ids?.isEmpty ?? false) { fail("No calendars matched filter '\(calFilter!)'") }
    let first = allCals.first
    let targetId = ids?.first ?? first?.identifier
    let targetCal = targetId.flatMap { id in allCals.first(where: { $0.identifier == id }) } ?? first
    let targetTitle = targetCal?.title ?? ""
    let endDate = edt.end ?? edt.start.addingTimeInterval(3600)
    let item = EventItem(
        identifier: "",
        title: title,
        startDate: edt.start,
        endDate: endDate,
        isAllDay: edt.isAllDay,
        calendarTitle: targetTitle,
        calendarIdentifier: targetId
    )
    let saved = try await store.add(item)
    try? ActivityLog.write(tool: "calendar", cmd: "add", desc: title, container: saved.calendarTitle)
    let detail = edt.isAllDay ? "all day" : "\(formatEventTime(edt.start)) – \(formatEventTime(endDate))"
    return "Added: \(title) · \(shortDateFormatter.string(from: edt.start)) \(detail) (\(saved.calendarTitle))"
}
