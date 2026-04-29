// ListHandler.swift
// Handlers for: list, today, week, next (bare range shorthands).

import Foundation
import GetClearKit

// MARK: - handleList

public func handleList(
    args: [String], store: any CalendarStore, calFilter: String?, config: CalendarConfig
) async throws -> String {
    guard args.count > 1 else {
        throw CalendarHandlerError("provide a range (e.g. today, week, 7d, \"march 15 to march 20\")")
    }
    let range = try parseRange(trailingArgs: args, default: "")
    return try await fetchAndFormat(store: store, calFilter: calFilter, config: config, range: range)
}

// MARK: - handleToday

public func handleToday(
    store: any CalendarStore, calFilter: String?, config: CalendarConfig
) async throws -> String {
    let range = parseRange("today")!
    let ids   = try await resolvedIdentifiers(calFilter: calFilter, config: config, store: store)
    if ids?.isEmpty == true { fail("No calendars matched filter '\(calFilter!)'") }
    let evts  = try await store.fetchEvents(in: range.interval, calendarIdentifiers: ids)
    let hdr   = dayHeaderFormatter.string(from: range.start)
    if evts.isEmpty { return "\(hdr)\n  (nothing scheduled)" }
    return formatFlat(evts, showHeader: true, header: hdr)
}

// MARK: - handleWeek

public func handleWeek(
    store: any CalendarStore, calFilter: String?, config: CalendarConfig
) async throws -> String {
    let range = parseRange("week")!
    let ids   = try await resolvedIdentifiers(calFilter: calFilter, config: config, store: store)
    if ids?.isEmpty == true { fail("No calendars matched filter '\(calFilter!)'") }
    let evts  = try await store.fetchEvents(in: range.interval, calendarIdentifiers: ids)
    if evts.isEmpty { return "No events this week" }
    return formatGrouped(evts)
}

// MARK: - handleDefault (bare range shorthands)

/// Returns a formatted string if args parse as a range; returns nil otherwise.
public func handleDefault(
    args: [String], store: any CalendarStore, calFilter: String?, config: CalendarConfig
) async throws -> String? {
    let rangeStr = args.joined(separator: " ")
    guard let range = parseRange(rangeStr) else { return nil }
    return try await fetchAndFormat(store: store, calFilter: calFilter, config: config, range: range)
}

// MARK: - Shared

private func fetchAndFormat(
    store: any CalendarStore, calFilter: String?, config: CalendarConfig, range: ParsedRange
) async throws -> String {
    let ids  = try await resolvedIdentifiers(calFilter: calFilter, config: config, store: store)
    if ids?.isEmpty == true { fail("No calendars matched filter '\(calFilter!)'") }
    let evts = try await store.fetchEvents(in: range.interval, calendarIdentifiers: ids)
    if evts.isEmpty { return "No events — \(formatRangeDescription(range))" }
    if range.isSingleDay {
        return formatFlat(evts, showHeader: true, header: dayHeaderFormatter.string(from: range.start))
    }
    return formatGrouped(evts)
}

func resolvedIdentifiers(calFilter: String?, config: CalendarConfig, store: any CalendarStore) async throws -> [String]? {
    guard calFilter != nil else { return nil }
    let cals = try await store.fetchCalendars()
    return resolveCalendarIdentifiers(filter: calFilter, calendars: cals, config: config)
}
