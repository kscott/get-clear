// ReminderSortingSpec.swift
// Tests for sorted(_:by:) and comparator(for:) — sort functions on ReminderItem arrays.

import Quick
import Nimble
import Foundation
import RemindersLib

final class ReminderSortingSpec: QuickSpec {
    override class func spec() {

        func makeItem(
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
                calendarTitle: "Test",
                dueDateComponents: comps,
                creationDate: creationOffset.map { now.addingTimeInterval($0) }
            )
        }

        describe("sorted") {

            context("by due") {
                it("sorts earlier due dates before later ones") {
                    let items = [makeItem(title: "B", dueOffset: 86400), makeItem(title: "A", dueOffset: 0)]
                    let result = sorted(items, by: .due)
                    expect(result[0].title) == "A"
                    expect(result[1].title) == "B"
                }
                it("places items without a due date after items with one") {
                    let items = [makeItem(title: "No due"), makeItem(title: "Has due", dueOffset: 0)]
                    let result = sorted(items, by: .due)
                    expect(result[0].title) == "Has due"
                    expect(result[1].title) == "No due"
                }
                it("sorts two nil-due items alphabetically by title") {
                    let items = [makeItem(title: "Zebra"), makeItem(title: "Apple")]
                    let result = sorted(items, by: .due)
                    expect(result[0].title) == "Apple"
                    expect(result[1].title) == "Zebra"
                }
            }

            context("by priority") {
                it("sorts high priority before low priority") {
                    let items = [makeItem(title: "Low", priority: 9), makeItem(title: "High", priority: 1)]
                    let result = sorted(items, by: .priority)
                    expect(result[0].title) == "High"
                    expect(result[1].title) == "Low"
                }
                it("treats priority 0 as lower than priority 9") {
                    let items = [makeItem(title: "None", priority: 0), makeItem(title: "Low", priority: 9)]
                    let result = sorted(items, by: .priority)
                    expect(result[0].title) == "Low"
                    expect(result[1].title) == "None"
                }
                it("falls back to due date when priorities are equal") {
                    let items = [
                        makeItem(title: "B", priority: 1, dueOffset: 86400),
                        makeItem(title: "A", priority: 1, dueOffset: 0)
                    ]
                    let result = sorted(items, by: .priority)
                    expect(result[0].title) == "A"
                }
            }

            context("by title") {
                it("sorts alphabetically case-insensitively") {
                    let items = [makeItem(title: "banana"), makeItem(title: "Apple"), makeItem(title: "Cherry")]
                    let result = sorted(items, by: .title)
                    expect(result[0].title) == "Apple"
                    expect(result[1].title) == "banana"
                    expect(result[2].title) == "Cherry"
                }
            }

            context("by created") {
                it("sorts earlier creation dates first") {
                    let items = [makeItem(title: "Newer", creationOffset: 0), makeItem(title: "Older", creationOffset: -86400)]
                    let result = sorted(items, by: .created)
                    expect(result[0].title) == "Older"
                    expect(result[1].title) == "Newer"
                }
                it("treats nil creation date as the oldest") {
                    let items = [makeItem(title: "Has creation", creationOffset: 0), makeItem(title: "No creation")]
                    let result = sorted(items, by: .created)
                    expect(result[0].title) == "No creation"
                }
            }
        }

        describe("comparator") {
            it("returns a comparator that sorts by due when order is .due") {
                let cmp = comparator(for: .due)
                let earlier = makeItem(title: "A", dueOffset: 0)
                let later   = makeItem(title: "B", dueOffset: 86400)
                expect(cmp(earlier, later)) == true
                expect(cmp(later, earlier)) == false
            }
            it("returns a comparator usable to sort (EKReminder, ReminderItem) pairs") {
                let cmp = comparator(for: .title)
                let a = makeItem(title: "Apple")
                let b = makeItem(title: "Banana")
                let pairs: [(String, ReminderItem)] = [("r2", b), ("r1", a)]
                let sorted = pairs.sorted { cmp($0.1, $1.1) }
                expect(sorted[0].0) == "r1"
            }
        }

        describe("ReminderSortOrder") {
            it("initialises from 'due'") {
                expect(ReminderSortOrder(rawValue: "due")) == .due
            }
            it("initialises from 'priority'") {
                expect(ReminderSortOrder(rawValue: "priority")) == .priority
            }
            it("initialises from 'title'") {
                expect(ReminderSortOrder(rawValue: "title")) == .title
            }
            it("initialises from 'created'") {
                expect(ReminderSortOrder(rawValue: "created")) == .created
            }
            it("returns nil for an unrecognised value") {
                expect(ReminderSortOrder(rawValue: "unknown")).to(beNil())
            }
        }
    }
}
