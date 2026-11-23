// ReminderHelperRequest.swift
//
// One case per ReminderStore method: what a command asks the Get Clear helper to do with
// Reminders (spec 018). Adding a store method means adding a case here, in
// RemoteReminderStore, and in ReminderDispatch.

import Foundation

public enum ReminderHelperRequest: Codable, Equatable, Sendable {
    case fetchLists
    case defaultList
    case fetchIncomplete(list: ReminderList?)
    case fetchCompleted(range: DateInterval)
    case add(ReminderItem)
    case update(identifier: String, changes: ReminderChanges)
    case complete(identifier: String)
    case rename(identifier: String, title: String)
    case delete(identifier: String)
}
