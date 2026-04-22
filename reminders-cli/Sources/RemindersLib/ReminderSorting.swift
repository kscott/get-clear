// ReminderSorting.swift
// Sorts a ReminderItem array by the user-specified field.

import Foundation

public enum ReminderSortOrder: String {
    case due, priority, title, created
}

public func sorted(_ items: [ReminderItem], by order: ReminderSortOrder) -> [ReminderItem] {
    items.sorted(by: comparator(for: order))
}

/// Returns the sort comparator for `order`, for use when sorting paired arrays in CLI.
public func comparator(for order: ReminderSortOrder) -> (ReminderItem, ReminderItem) -> Bool {
    switch order {
    case .due:      return byDue
    case .priority: return byPriority
    case .title:    return byTitle
    case .created:  return byCreated
    }
}

private func dueDate(of item: ReminderItem) -> Date? {
    item.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
}

private func byDue(_ a: ReminderItem, _ b: ReminderItem) -> Bool {
    switch (dueDate(of: a), dueDate(of: b)) {
    case (nil, nil):         return a.title < b.title
    case (nil, _):           return false
    case (_, nil):           return true
    case (let da?, let db?): return da < db
    }
}

private func byPriority(_ a: ReminderItem, _ b: ReminderItem) -> Bool {
    let pa = a.priority == 0 ? 10 : a.priority
    let pb = b.priority == 0 ? 10 : b.priority
    return pa != pb ? pa < pb : byDue(a, b)
}

private func byTitle(_ a: ReminderItem, _ b: ReminderItem) -> Bool {
    a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
}

private func byCreated(_ a: ReminderItem, _ b: ReminderItem) -> Bool {
    (a.creationDate ?? .distantPast) < (b.creationDate ?? .distantPast)
}
