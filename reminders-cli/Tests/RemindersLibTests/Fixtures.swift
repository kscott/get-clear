// Fixtures.swift
// Shared test data and mocks for RemindersLibTests.

import Foundation
import RemindersLib

// MARK: - SpyStore

final class SpyStore: ReminderStore {
    var lists: [ReminderList] = []
    var items: [ReminderItem] = []

    var addedItems: [ReminderItem] = []
    var completedIds: [String] = []
    var deletedIds: [String] = []
    var renamedItems: [(id: String, to: String)] = []
    var updatedItems: [(id: String, changes: ReminderChanges)] = []

    func fetchLists() async throws -> [ReminderList] {
        lists
    }

    func defaultList() async throws -> ReminderList {
        lists.first ?? ReminderList(title: "Reminders")
    }

    func fetchIncomplete(in list: ReminderList?) async throws -> [ReminderItem] {
        items
    }

    func add(_ item: ReminderItem) async throws -> ReminderItem {
        addedItems.append(item)
        return item
    }

    func update(identifier: String, changes: ReminderChanges) async throws {
        updatedItems.append((identifier, changes))
    }

    func complete(identifier: String) async throws {
        completedIds.append(identifier)
    }

    func rename(identifier: String, to title: String) async throws {
        renamedItems.append((identifier, title))
    }

    func delete(identifier: String) async throws {
        deletedIds.append(identifier)
    }
}

// MARK: - Shared list constants

let testList = ReminderList(title: "Test")
let personalList = ReminderList(title: "Personal")
let workList = ReminderList(title: "Work")

// MARK: - Item factory

func ambiguousItems(title: String = "Pay rent", list: ReminderList = personalList) -> [ReminderItem] {
    [makeItem(identifier: "id-1", title: title, list: list),
     makeItem(identifier: "id-2", title: title, list: list)]
}

func makeItem(
    identifier: String = "",
    title: String = "Pay rent",
    list: ReminderList = personalList,
    dueDateComponents: DateComponents? = nil,
    priority: Int = 0,
    notes: String? = nil,
    url: URL? = nil,
    creationDate: Date? = nil,
    recurrenceDescription: String? = nil
) -> ReminderItem {
    ReminderItem(
        identifier: identifier,
        title: title,
        list: list,
        dueDateComponents: dueDateComponents,
        recurrenceDescription: recurrenceDescription,
        priority: priority,
        notes: notes,
        url: url,
        creationDate: creationDate
    )
}
