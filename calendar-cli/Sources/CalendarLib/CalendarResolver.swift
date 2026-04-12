// CalendarResolver.swift
//
// Resolves a subset filter string to matching calendar identifiers using config.

import Foundation

/// A calendar name and its unique identifier, extracted from EKCalendar in CalendarCLI.
public struct CalendarEntry {
    public let name:       String
    public let identifier: String

    public init(name: String, identifier: String) {
        self.name       = name
        self.identifier = identifier
    }
}

/// Returns the identifiers from `entries` that match `filter` against `config` subsets.
/// Returns all identifiers when `filter` is nil.
/// Returns an empty array when `filter` names a subset not found in config.
public func resolveCalendarIdentifiers(
    filter:  String?,
    entries: [CalendarEntry],
    config:  CalendarConfig
) -> [String] {
    guard let filter else { return entries.map(\.identifier) }
    guard let names = config.subsets[filter.lowercased()] else { return [] }
    return entries.filter { names.contains($0.name) }.map(\.identifier)
}
