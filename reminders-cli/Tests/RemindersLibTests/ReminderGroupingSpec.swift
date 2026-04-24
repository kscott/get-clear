// ReminderGroupingSpec.swift
//
// Tests for ReminderGrouping — grouping ReminderItems by list.

import Quick
import Nimble
import RemindersLib

final class ReminderGroupingSpec: QuickSpec {
    override class func spec() {
        describe("groupedByList") {
            context("single list") {
                it("returns one group with the correct list title") {
                    let items = [
                        ReminderItem(title: "Buy milk", list: ReminderList(title: "Shopping")),
                        ReminderItem(title: "Buy eggs", list: ReminderList(title: "Shopping")),
                    ]
                    let groups = groupedByList(items, sortedBy: .title)
                    expect(groups.count) == 1
                    expect(groups[0].list.title) == "Shopping"
                }
                it("sorts items within the group by the given order") {
                    let items = [
                        ReminderItem(title: "Zucchini", list: ReminderList(title: "Shopping")),
                        ReminderItem(title: "Apples",   list: ReminderList(title: "Shopping")),
                    ]
                    let groups = groupedByList(items, sortedBy: .title)
                    expect(groups[0].items.map(\.title)) == ["Apples", "Zucchini"]
                }
            }
            context("multiple lists") {
                it("returns groups sorted alphabetically by list title") {
                    let items = [
                        ReminderItem(title: "Task A", list: ReminderList(title: "Work")),
                        ReminderItem(title: "Task B", list: ReminderList(title: "Personal")),
                        ReminderItem(title: "Task C", list: ReminderList(title: "Home")),
                    ]
                    let groups = groupedByList(items, sortedBy: .title)
                    expect(groups.map { $0.list.title }) == ["Home", "Personal", "Work"]
                }
                it("places each item in the correct group") {
                    let items = [
                        ReminderItem(title: "Task A", list: ReminderList(title: "Work")),
                        ReminderItem(title: "Task B", list: ReminderList(title: "Personal")),
                    ]
                    let groups = groupedByList(items, sortedBy: .title)
                    let personal = groups.first(where: { $0.list.title == "Personal" })
                    expect(personal?.items.map(\.title)) == ["Task B"]
                }
            }
            context("empty input") {
                it("returns an empty array") {
                    expect(groupedByList([], sortedBy: .due)).to(beEmpty())
                }
            }
        }
    }
}
