// ReminderChangeParsing.swift
// Parses a combined options string into a value describing what fields should change.
// No EventKit dependency — lives in RemindersLib so it can be unit tested.

import Foundation
import GetClearKit

/// The resolved set of changes to apply to a reminder.
public struct ReminderChanges {
    /// Due date as DateComponents ready to assign to EKReminder.dueDateComponents, or cleared/unchanged.
    public let due: ValueChange<DateComponents>
    public let recurrence: ValueChange<RecurrenceSpec>
    /// Priority integer (0 = none, 1 = high, 5 = medium, 9 = low), or unchanged.
    public let priority: ValueChange<Int>
    public let note: ValueChange<String>
    public let url: ValueChange<URL>
    /// Target list name. Caller is responsible for resolving to EKCalendar and generating the description.
    public let list: ValueChange<String>
    /// Human-readable summary of changes made (excludes list — caller appends that).
    public var descriptions: [String]
}

/// Errors thrown by parseReminderChanges.
public enum ReminderChangeError: Error, Equatable {
    case nothingToChange
    case unrecognizedRecurrence(String)
    case unrecognizedPriority(String)
}

/// Converts a priority string to an EventKit priority integer.
/// Returns nil for unrecognized input.
public func parsePriority(_ s: String) -> Int? {
    switch s.lowercased().trimmingCharacters(in: .whitespaces) {
    case "high": 1
    case "medium", "med": 5
    case "low": 9
    case "none": 0
    default: nil
    }
}

/// Parses opts into a ReminderChanges value describing what to apply.
///
/// - Parameter opts: Parsed options from the user's input string.
/// - Parameter existingItem: The current reminder, used to populate `from:` in ValueChange.replaced
///   and to merge time-only input (e.g. "3pm") with an existing due date.
/// - Throws: `ReminderChangeError.nothingToChange` if no recognized fields were specified.
/// - Throws: `ReminderChangeError.unrecognizedRecurrence` if a repeat value was given but not parseable.
public func parseReminderChanges(
    _ opts: ParsedOptions,
    existingItem: ReminderItem
) throws -> ReminderChanges {
    // `due none` clears the date independently of every other field below — it arrives via the
    // `due` keyword now, so it is never dropped when another keyword precedes it (FR-012).
    let (due, dueDescription) = changedDue(opts, existingItem: existingItem)
    let (recurrence, recurrenceDescription) = try changedRecurrence(opts, existingItem: existingItem)
    let (priority, priorityDescription) = try changedPriority(opts, existingItem: existingItem)
    let (note, noteDescription) = changedNote(opts, existingItem: existingItem)
    let (url, urlDescription) = changedURL(opts, existingItem: existingItem)
    let list: ValueChange<String> = opts.list.isEmpty
        ? .unchanged : .replaced(from: existingItem.list.title, to: opts.list)

    let descriptions = [dueDescription, recurrenceDescription, priorityDescription, noteDescription, urlDescription]
        .compactMap(\.self)

    if descriptions.isEmpty, opts.list.isEmpty {
        throw ReminderChangeError.nothingToChange
    }

    return ReminderChanges(
        due: due, recurrence: recurrence, priority: priority,
        note: note, url: url, list: list, descriptions: descriptions
    )
}

private func changedDue(
    _ opts: ParsedOptions, existingItem: ReminderItem
) -> (ValueChange<DateComponents>, String?) {
    guard !opts.date.isEmpty else { return (.unchanged, nil) }
    if opts.date.lowercased() == "none" {
        return (.cleared, "due cleared")
    }
    guard let pd = parseDate(opts.date) else { return (.unchanged, nil) }
    let cal = Calendar.current
    if pd.hasTime, !pd.hasDate, let existing = existingItem.dueDateComponents {
        // Time-only input — preserve existing date, update time only
        var comps = existing
        let t = cal.dateComponents([.hour, .minute], from: pd.date)
        comps.hour = t.hour
        comps.minute = t.minute
        let display = cal.date(from: comps) ?? pd.date
        return (.replaced(from: existing, to: comps), "due → \(formatDate(display, showTime: true))")
    }
    let comps = dateComponents(from: pd)
    let change: ValueChange<DateComponents> = if let existing = existingItem.dueDateComponents {
        .replaced(from: existing, to: comps)
    } else {
        .added(comps)
    }
    return (change, "due → \(formatDate(pd.date, showTime: pd.hasTime))")
}

private func changedRecurrence(
    _ opts: ParsedOptions, existingItem: ReminderItem
) throws -> (ValueChange<RecurrenceSpec>, String?) {
    guard !opts.recurrence.isEmpty else { return (.unchanged, nil) }
    if opts.recurrence.lowercased() == "none" {
        return (.cleared, "repeat cleared")
    }
    guard let spec = parseRecurrence(opts.recurrence) else {
        throw ReminderChangeError.unrecognizedRecurrence(opts.recurrence)
    }
    let change: ValueChange<RecurrenceSpec> = if let existing = existingItem.recurrenceSpec {
        .replaced(from: existing, to: spec)
    } else {
        .added(spec)
    }
    return (change, describeRecurrence(spec))
}

private func changedPriority(
    _ opts: ParsedOptions, existingItem: ReminderItem
) throws -> (ValueChange<Int>, String?) {
    guard !opts.priority.isEmpty else { return (.unchanged, nil) }
    guard let p = parsePriority(opts.priority) else {
        throw ReminderChangeError.unrecognizedPriority(opts.priority)
    }
    return (.replaced(from: existingItem.priority, to: p), p == 0 ? "priority cleared" : "priority → \(opts.priority)")
}

private func changedNote(_ opts: ParsedOptions, existingItem: ReminderItem) -> (ValueChange<String>, String?) {
    guard !opts.note.isEmpty else { return (.unchanged, nil) }
    if opts.note.lowercased() == "none" {
        return (.cleared, "note cleared")
    }
    let change: ValueChange<String> = if let existing = existingItem.notes {
        .replaced(from: existing, to: opts.note)
    } else {
        .added(opts.note)
    }
    return (change, "+ note")
}

private func changedURL(_ opts: ParsedOptions, existingItem: ReminderItem) -> (ValueChange<URL>, String?) {
    guard !opts.url.isEmpty else { return (.unchanged, nil) }
    if opts.url.lowercased() == "none" {
        return (.cleared, "url cleared")
    }
    guard let parsed = URL(string: opts.url) else { return (.unchanged, nil) }
    let change: ValueChange<URL> = if let existing = existingItem.url {
        .replaced(from: existing, to: parsed)
    } else {
        .added(parsed)
    }
    return (change, "url → \(opts.url)")
}
