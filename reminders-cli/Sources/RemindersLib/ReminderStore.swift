// ReminderStore.swift
// Protocol for reminder data access; default resolve extension for single-item lookup.

import Foundation

public enum ReminderStoreError: Error, Equatable {
    case notFound(String)
    case ambiguous([ReminderItem])
}

public protocol ReminderStore {
    func fetchLists() async throws -> [ReminderList]
    func defaultList() async throws -> ReminderList
    func fetchIncomplete(in list: ReminderList?) async throws -> [ReminderItem]
    func add(_ item: ReminderItem) async throws -> ReminderItem
    func update(identifier: String, changes: ReminderChanges) async throws
    func complete(identifier: String) async throws
    func rename(identifier: String, to title: String) async throws
    func delete(identifier: String) async throws
}

public extension ReminderStore {
    func resolve(title: String, in list: ReminderList?, cmd: String) async throws -> ReminderItem {
        let items = try await fetchIncomplete(in: list)
        switch lookup(title: title, in: items) {
        case .found(let i):
            return items[i]
        case .notFound:
            throw ReminderStoreError.notFound(title)
        case .ambiguous(let indices):
            throw ReminderStoreError.ambiguous(indices.map { items[$0] })
        }
    }
}
