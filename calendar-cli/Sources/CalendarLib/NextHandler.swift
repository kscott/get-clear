// NextHandler.swift

import Foundation
import GetClearKit

public func handleNext(
    args: [String], store: any CalendarStore, calFilter: String?, config: CalendarConfig
) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: CalendarCommandShapes.next, wrapError: CalendarHandlerError.init
    )
    let n: Int
    if let countStr = parsed.identifiers.first {
        guard let count = Int(countStr) else {
            throw CalendarHandlerError("invalid count: \(countStr)")
        }
        n = count
    } else {
        n = 5
    }
    let now = Date()
    let ids = try await resolvedIdentifiers(calFilter: calFilter, config: config, store: store)
    let upcoming = try await store.fetchEvents(in: literalRange("90d").interval, calendarIdentifiers: ids)
        .filter { ($0.endDate ?? $0.startDate) > now }
        .prefix(n)
    if upcoming.isEmpty { return "No upcoming events in the next 90 days" }
    return upcoming.map { e in
        let lbl = nextRelativeLabel(for: e.startDate, relativeTo: now)
        let time = e.isAllDay ? "All day  " : formatEventTime(e.startDate)
        var txt = e.title
        if let loc = e.location, !loc.isEmpty {
            txt += " · " + (loc.components(separatedBy: "\n").first ?? loc)
        }
        return "\(calendarDot(hex: e.calendarColor)) \(lbl)  \(time)   \(txt)"
    }.joined(separator: "\n")
}
