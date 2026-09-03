// AddHandler.swift

import Foundation
import GetClearKit

public func handleAdd(
    args: [String], store: any CalendarStore, calFilter: String?, config: CalendarConfig
) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: CalendarCommandShapes.add, wrapError: CalendarHandlerError.init
    )
    let title = parsed.identifiers[0]
    let dStr = parsed.bareDateRange ?? ""
    guard let edt = parseEventDateTime(dStr.isEmpty ? "today" : dStr) else {
        throw CalendarHandlerError("unrecognised date/time: \(dStr)")
    }
    let allCals = try await store.fetchCalendars()
    let ids = resolveCalendarIdentifiers(filter: calFilter, calendars: allCals, config: config)
    if let f = calFilter, ids?.isEmpty ?? false { fail("No calendars matched filter '\(f)'") }
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
