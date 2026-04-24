// ReminderFormatter.swift
//
// Formats ReminderItem data into display strings for all reminder commands.
// No EventKit dependency — calendarDot (which requires EKCalendar) stays in CLI.

import Foundation
import GetClearKit

/// Metadata needed to format the display suffix for a single reminder.
public struct ReminderMeta {
    /// Due date already formatted by the caller (e.g. "Fri Apr 11 · 3:00pm"), or nil if no due date.
    public let formattedDue: String?
    public let isRepeating: Bool
    /// Raw EventKit priority integer: 0 = none, 1–4 = high, 5 = medium, 6–9 = low.
    public let priority: Int
    public let hasNote: Bool
    public let hasURL: Bool

    public init(
        formattedDue: String? = nil,
        isRepeating: Bool = false,
        priority: Int = 0,
        hasNote: Bool = false,
        hasURL: Bool = false
    ) {
        self.formattedDue = formattedDue
        self.isRepeating  = isRepeating
        self.priority     = priority
        self.hasNote      = hasNote
        self.hasURL       = hasURL
    }
}

// MARK: - metaLine (supporting type for list/find rows)

/// Returns the dim metadata suffix for a reminder, e.g. "  ·  due Fri Apr 11 · repeating · high".
/// Returns "" when no metadata fields are present.
public func metaLine(for meta: ReminderMeta) -> String {
    var parts: [String] = []
    if let due = meta.formattedDue { parts.append(due) }
    if meta.isRepeating { parts.append("repeating") }
    switch meta.priority {
    case 1...4: parts.append("high")
    case 5:     parts.append("medium")
    case 6...9: parts.append("low")
    default:    break
    }
    if meta.hasNote { parts.append("+ note") }
    if meta.hasURL  { parts.append("+ url") }
    return parts.isEmpty ? "" : "  ·  " + parts.joined(separator: " · ")
}

// MARK: - Row formatters (prepend calendarDot in CLI)

/// Returns the formatted row for a find result — bold title + dim list + optional due.
/// The caller prepends calendarDot(reminder.calendar).
public func formatFindRow(_ item: ReminderItem) -> String {
    var meta = "  [\(item.calendarTitle)]"
    if let comps = item.dueDateComponents, let date = Calendar.current.date(from: comps) {
        meta = "  ·  due \(formatDate(date, showTime: comps.hour != nil))" + meta
    }
    return "\(ANSI.bold(item.title))\(ANSI.dim(meta))"
}

/// Returns the formatted row for a list entry — bold title + dim metadata suffix.
/// The caller prepends calendarDot(reminder.calendar).
public func formatListRow(_ item: ReminderItem) -> String {
    let formattedDue: String? = item.dueDateComponents.flatMap { comps in
        Calendar.current.date(from: comps).map { formatDate($0, showTime: comps.hour != nil) }
    }
    let meta = metaLine(for: ReminderMeta(
        formattedDue: formattedDue,
        isRepeating:  item.hasRecurrenceRules,
        priority:     item.priority,
        hasNote:      item.notes != nil,
        hasURL:       item.url != nil
    ))
    return "\(ANSI.bold(item.title))\(ANSI.dim(meta))"
}

// MARK: - Show formatter

/// Returns the full detail block for the `show` command.
/// `repeatDescription` is produced by the CLI from EKRecurrenceRule (which requires EventKit).
public func formatShow(item: ReminderItem, repeatDescription: String?) -> String {
    var lines: [String] = []
    lines.append("Title:    \(item.title)")
    lines.append("List:     \(item.calendarTitle)")
    if let comps = item.dueDateComponents, let date = Calendar.current.date(from: comps) {
        lines.append("Due:      \(formatDate(date, showTime: comps.hour != nil))")
    }
    if let desc = repeatDescription {
        lines.append("Repeat:   \(desc)")
    }
    switch item.priority {
    case 1...4: lines.append("Priority: high")
    case 5:     lines.append("Priority: medium")
    case 6...9: lines.append("Priority: low")
    default:    break
    }
    if let notes = item.notes, !notes.isEmpty { lines.append("Note:     \(notes)") }
    if let url = item.url                      { lines.append("URL:      \(url)") }
    return lines.joined(separator: "\n")
}

// MARK: - Add confirmation

/// Returns the confirmation line printed after a reminder is successfully added.
public func formatAddConfirmation(
    title: String,
    list: String,
    date: ParsedDate?,
    recurrence: RecurrenceSpec?,
    priority: String,
    hasNote: Bool,
    url: String
) -> String {
    var parts = ["Added: \(title) (in \(list))"]
    if let pd = date      { parts.append("due \(formatDate(pd.date, showTime: pd.hasTime))") }
    if let s = recurrence { parts.append(describeRecurrence(s)) }
    if !priority.isEmpty  { parts.append("priority \(priority)") }
    if hasNote            { parts.append("+ note") }
    if !url.isEmpty       { parts.append("url \(url)") }
    return parts.joined(separator: " · ")
}

// MARK: - Lookup messages

public func notFoundMessage(title: String, list: String?) -> String {
    list.map { "Not found: \(title) in \($0)" } ?? "Not found: \(title)"
}

public func disambiguationMessage(title: String, matches: [ReminderItem], cmd: String) -> String {
    var lines = ["Multiple reminders named '\(title)':"]
    for m in matches { lines.append("  [\(m.calendarTitle)]") }
    lines.append("Add the list name to narrow: reminders \(cmd) \"\(title)\" \(matches[0].calendarTitle)")
    return lines.joined(separator: "\n")
}
