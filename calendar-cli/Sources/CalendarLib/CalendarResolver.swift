// CalendarResolver.swift
// Resolves a subset filter string to matching calendar identifiers using config.

import Foundation

/// Returns the identifiers from `calendars` that match `filter` against `config` subsets.
/// Returns all identifiers when `filter` is nil.
/// Returns an empty array when `filter` names a subset not found in config.
public func resolveCalendarIdentifiers(
    filter: String?,
    calendars: [CalendarItem],
    config: CalendarConfig
) -> [String]? {
    guard let filter else { return nil }
    guard let names = config.subsets[filter.lowercased()] else { return [] }
    return calendars.filter { names.contains($0.title) }.map(\.identifier)
}
