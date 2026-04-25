// Fixtures.swift
// Shared test data for RemindersLibTests.

import Foundation
import RemindersLib

// MARK: - Shared list constants

let testList     = ReminderList(title: "Test")
let personalList = ReminderList(title: "Personal")
let workList     = ReminderList(title: "Work")

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
