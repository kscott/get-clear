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
    var due: ValueChange<DateComponents> = .unchanged
    var recurrence: ValueChange<RecurrenceSpec> = .unchanged
    var priority: ValueChange<Int> = .unchanged
    var note: ValueChange<String> = .unchanged
    var url: ValueChange<URL> = .unchanged
    var list: ValueChange<String> = .unchanged
    var descriptions: [String] = []

    if !opts.date.isEmpty {
        if opts.date.lowercased() == "none" {
            due = .cleared
            descriptions.append("due cleared")
        } else if let pd = parseDate(opts.date) {
            let cal = Calendar.current
            if pd.hasTime, !pd.hasDate, let existing = existingItem.dueDateComponents {
                // Time-only input — preserve existing date, update time only
                var comps = existing
                let t = cal.dateComponents([.hour, .minute], from: pd.date)
                comps.hour = t.hour
                comps.minute = t.minute
                let display = cal.date(from: comps) ?? pd.date
                due = .replaced(from: existing, to: comps)
                descriptions.append("due → \(formatDate(display, showTime: true))")
            } else {
                let comps = dateComponents(from: pd)
                if let existing = existingItem.dueDateComponents {
                    due = .replaced(from: existing, to: comps)
                } else {
                    due = .added(comps)
                }
                descriptions.append("due → \(formatDate(pd.date, showTime: pd.hasTime))")
            }
        }
    }

    if !opts.recurrence.isEmpty {
        if opts.recurrence.lowercased() == "none" {
            recurrence = .cleared
            descriptions.append("repeat cleared")
        } else if let spec = parseRecurrence(opts.recurrence) {
            if let existing = existingItem.recurrenceSpec {
                recurrence = .replaced(from: existing, to: spec)
            } else {
                recurrence = .added(spec)
            }
            descriptions.append(describeRecurrence(spec))
        } else {
            throw ReminderChangeError.unrecognizedRecurrence(opts.recurrence)
        }
    }

    if !opts.priority.isEmpty, let p = parsePriority(opts.priority) {
        priority = .replaced(from: existingItem.priority, to: p)
        descriptions.append(p == 0 ? "priority cleared" : "priority → \(opts.priority)")
    }

    if !opts.note.isEmpty {
        if opts.note.lowercased() == "none" {
            note = .cleared
            descriptions.append("note cleared")
        } else {
            note = existingItem.notes.map { .replaced(from: $0, to: opts.note) } ?? .added(opts.note)
            descriptions.append("+ note")
        }
    }

    if !opts.url.isEmpty {
        if opts.url.lowercased() == "none" {
            url = .cleared
            descriptions.append("url cleared")
        } else if let parsed = URL(string: opts.url) {
            if let existing = existingItem.url {
                url = .replaced(from: existing, to: parsed)
            } else {
                url = .added(parsed)
            }
            descriptions.append("url → \(opts.url)")
        }
    }

    if !opts.list.isEmpty {
        list = .replaced(from: existingItem.list.title, to: opts.list)
    }

    if descriptions.isEmpty, opts.list.isEmpty {
        throw ReminderChangeError.nothingToChange
    }

    return ReminderChanges(
        due: due, recurrence: recurrence, priority: priority,
        note: note, url: url, list: list, descriptions: descriptions
    )
}
