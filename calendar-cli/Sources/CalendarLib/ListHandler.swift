// ListHandler.swift
// Handlers for: list, today, week.

import Foundation
import GetClearKit

// MARK: - handleList

public func handleList(
    args: [String], store: any CalendarStore, calFilter: String?, config: CalendarConfig
) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: CalendarCommandShapes.list, wrapError: CalendarHandlerError.init
    )
    guard let rangeStr = parsed.bareDateRange else {
        throw CalendarHandlerError("provide a range (e.g. today, week, 7d, \"march 15 to march 20\")")
    }
    guard let range = parseRange(rangeStr) else {
        throw CalendarHandlerError("unrecognised range: \(rangeStr)")
    }
    return try await fetchAndFormat(store: store, calFilter: calFilter, config: config, range: range)
}

// MARK: - handleToday

public func handleToday(
    args: [String], store: any CalendarStore, calFilter: String?, config: CalendarConfig
) async throws -> String {
    _ = try parseCommand(
        Array(args.dropFirst()), shape: CalendarCommandShapes.today, wrapError: CalendarHandlerError.init
    )
    let range = parseRange("today")!
    let ids = try await resolvedIdentifiers(calFilter: calFilter, config: config, store: store)
    if ids?.isEmpty == true { fail("No calendars matched filter '\(calFilter!)'") }
    let evts = try await store.fetchEvents(in: range.interval, calendarIdentifiers: ids)
    let hdr = dayHeaderFormatter.string(from: range.start)
    if evts.isEmpty { return "\(hdr)\n  (nothing scheduled)" }
    return formatFlat(evts, showHeader: true, header: hdr)
}

// MARK: - handleWeek

public func handleWeek(
    args: [String], store: any CalendarStore, calFilter: String?, config: CalendarConfig
) async throws -> String {
    _ = try parseCommand(
        Array(args.dropFirst()), shape: CalendarCommandShapes.week, wrapError: CalendarHandlerError.init
    )
    let range = parseRange("week")!
    let ids = try await resolvedIdentifiers(calFilter: calFilter, config: config, store: store)
    if ids?.isEmpty == true { fail("No calendars matched filter '\(calFilter!)'") }
    let evts = try await store.fetchEvents(in: range.interval, calendarIdentifiers: ids)
    if evts.isEmpty { return "No events this week" }
    return formatGrouped(evts)
}

// MARK: - Shared

private func fetchAndFormat(
    store: any CalendarStore, calFilter: String?, config: CalendarConfig, range: ParsedRange
) async throws -> String {
    let ids = try await resolvedIdentifiers(calFilter: calFilter, config: config, store: store)
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

/// Resolves an optional bareDateRange string to a ParsedRange, defaulting to 30 days when
/// absent. Throws, naming the string, when it's present but unparseable (FR-024) — never
/// silently falls back to the default.
func resolvedRange(_ rangeStr: String?) throws -> ParsedRange {
    guard let rangeStr else { return parseRange("30d")! }
    guard let r = parseRange(rangeStr) else {
        throw CalendarHandlerError("unrecognised range: \(rangeStr)")
    }
    return r
}
