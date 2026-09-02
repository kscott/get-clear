// ReminderGroupingSpec.swift
//
// Tests for ReminderGrouping — grouping ReminderItems by list.

import RemindersLib
import Testing

@Suite("groupedByList")
struct ReminderGroupingTests {
    @Suite("single list")
    struct SingleList {
        @Test("returns one group with the correct list title")
        func oneGroupCorrectTitle() {
            let items = [
                ReminderItem(title: "Buy milk", list: ReminderList(title: "Shopping")),
                ReminderItem(title: "Buy eggs", list: ReminderList(title: "Shopping"))
            ]
            let groups = groupedByList(items, sortedBy: .title)
            #expect(groups.count == 1)
            #expect(groups[0].list.title == "Shopping")
        }

        @Test("sorts items within the group by the given order")
        func sortsItemsWithinGroup() {
            let items = [
                ReminderItem(title: "Zucchini", list: ReminderList(title: "Shopping")),
                ReminderItem(title: "Apples", list: ReminderList(title: "Shopping"))
            ]
            let groups = groupedByList(items, sortedBy: .title)
            #expect(groups[0].items.map(\.title) == ["Apples", "Zucchini"])
        }
    }

    @Suite("multiple lists")
    struct MultipleLists {
        @Test("returns groups sorted alphabetically by list title")
        func groupsSortedAlphabetically() {
            let items = [
                ReminderItem(title: "Task A", list: ReminderList(title: "Work")),
                ReminderItem(title: "Task B", list: ReminderList(title: "Personal")),
                ReminderItem(title: "Task C", list: ReminderList(title: "Home"))
            ]
            let groups = groupedByList(items, sortedBy: .title)
            #expect(groups.map(\.list.title) == ["Home", "Personal", "Work"])
        }

        @Test("places each item in the correct group")
        func placesItemsCorrectly() {
            let items = [
                ReminderItem(title: "Task A", list: ReminderList(title: "Work")),
                ReminderItem(title: "Task B", list: ReminderList(title: "Personal"))
            ]
            let groups = groupedByList(items, sortedBy: .title)
            let personal = groups.first(where: { $0.list.title == "Personal" })
            #expect(personal?.items.map(\.title) == ["Task B"])
        }
    }

    @Suite("empty input")
    struct EmptyInput {
        @Test("returns an empty array")
        func returnsEmptyArray() {
            #expect(groupedByList([], sortedBy: .due).isEmpty)
        }
    }
}
