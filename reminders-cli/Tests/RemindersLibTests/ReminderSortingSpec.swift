// ReminderSortingSpec.swift
// Tests for sorted(_:by:) and comparator(for:) — sort functions on ReminderItem arrays.

import Foundation
import RemindersLib
import Testing

private func makeItem(
    title: String = "Item",
    priority: Int = 0,
    dueOffset: TimeInterval? = nil,
    creationOffset: TimeInterval? = nil
) -> ReminderItem {
    let now = Date()
    let comps: DateComponents? = dueOffset.map {
        Calendar.current.dateComponents([.year, .month, .day], from: now.addingTimeInterval($0))
    }
    return ReminderItem(
        title: title,
        list: testList,
        dueDateComponents: comps,
        priority: priority,
        creationDate: creationOffset.map { now.addingTimeInterval($0) }
    )
}

@Suite("sorted")
struct ReminderSortingTests {
    @Suite("by due")
    struct ByDue {
        @Test("sorts earlier due dates before later ones")
        func earlierBeforeLater() {
            let items = [makeItem(title: "B", dueOffset: 86400), makeItem(title: "A", dueOffset: 0)]
            let result = sorted(items, by: .due)
            #expect(result[0].title == "A")
            #expect(result[1].title == "B")
        }

        @Test("places items without a due date after items with one")
        func noDueAfterHasDue() {
            let items = [makeItem(title: "No due"), makeItem(title: "Has due", dueOffset: 0)]
            let result = sorted(items, by: .due)
            #expect(result[0].title == "Has due")
            #expect(result[1].title == "No due")
        }

        @Test("sorts two nil-due items alphabetically by title")
        func nilDueSortedByTitle() {
            let items = [makeItem(title: "Zebra"), makeItem(title: "Apple")]
            let result = sorted(items, by: .due)
            #expect(result[0].title == "Apple")
            #expect(result[1].title == "Zebra")
        }
    }

    @Suite("by priority")
    struct ByPriority {
        @Test("sorts high priority before low priority")
        func highBeforeLow() {
            let items = [makeItem(title: "Low", priority: 9), makeItem(title: "High", priority: 1)]
            let result = sorted(items, by: .priority)
            #expect(result[0].title == "High")
            #expect(result[1].title == "Low")
        }

        @Test("treats priority 0 as lower than priority 9")
        func zeroLowerThanNine() {
            let items = [makeItem(title: "None", priority: 0), makeItem(title: "Low", priority: 9)]
            let result = sorted(items, by: .priority)
            #expect(result[0].title == "Low")
            #expect(result[1].title == "None")
        }

        @Test("falls back to due date when priorities are equal")
        func fallsBackToDue() {
            let items = [
                makeItem(title: "B", priority: 1, dueOffset: 86400),
                makeItem(title: "A", priority: 1, dueOffset: 0)
            ]
            let result = sorted(items, by: .priority)
            #expect(result[0].title == "A")
        }
    }

    @Suite("by title")
    struct ByTitle {
        @Test("sorts alphabetically case-insensitively")
        func alphabeticalCaseInsensitive() {
            let items = [makeItem(title: "banana"), makeItem(title: "Apple"), makeItem(title: "Cherry")]
            let result = sorted(items, by: .title)
            #expect(result[0].title == "Apple")
            #expect(result[1].title == "banana")
            #expect(result[2].title == "Cherry")
        }
    }

    @Suite("by created")
    struct ByCreated {
        @Test("sorts earlier creation dates first")
        func earlierCreationFirst() {
            let items = [makeItem(title: "Newer", creationOffset: 0), makeItem(title: "Older", creationOffset: -86400)]
            let result = sorted(items, by: .created)
            #expect(result[0].title == "Older")
            #expect(result[1].title == "Newer")
        }

        @Test("treats nil creation date as the oldest")
        func nilCreationOldest() {
            let items = [makeItem(title: "Has creation", creationOffset: 0), makeItem(title: "No creation")]
            let result = sorted(items, by: .created)
            #expect(result[0].title == "No creation")
        }
    }
}

@Suite("comparator")
struct ComparatorTests {
    @Test("returns a comparator that sorts by due when order is .due")
    func comparatorByDue() {
        let cmp = comparator(for: .due)
        let earlier = makeItem(title: "A", dueOffset: 0)
        let later = makeItem(title: "B", dueOffset: 86400)
        #expect(cmp(earlier, later))
        #expect(!cmp(later, earlier))
    }

    @Test("returns a comparator usable to sort paired arrays")
    func comparatorForPairedArrays() {
        let cmp = comparator(for: .title)
        let a = makeItem(title: "Apple")
        let b = makeItem(title: "Banana")
        let pairs: [(String, ReminderItem)] = [("r2", b), ("r1", a)]
        let sorted = pairs.sorted { cmp($0.1, $1.1) }
        #expect(sorted[0].0 == "r1")
    }
}

@Suite("ReminderSortOrder")
struct ReminderSortOrderTests {
    @Test("initialises from 'due'") func fromDue() {
        #expect(ReminderSortOrder(rawValue: "due") == .due)
    }

    @Test("initialises from 'priority'") func fromPriority() {
        #expect(ReminderSortOrder(rawValue: "priority") == .priority)
    }

    @Test("initialises from 'title'") func fromTitle() {
        #expect(ReminderSortOrder(rawValue: "title") == .title)
    }

    @Test("initialises from 'created'") func fromCreated() {
        #expect(ReminderSortOrder(rawValue: "created") == .created)
    }

    @Test("returns nil for an unrecognised value") func nilForUnrecognised() {
        #expect(ReminderSortOrder(rawValue: "unknown") == nil)
    }
}
