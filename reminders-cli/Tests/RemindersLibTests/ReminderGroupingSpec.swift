// ReminderGroupingSpec.swift
//
// Tests for ReminderGrouping — grouping ReminderItems by list name.

import Quick
import Nimble
import RemindersLib

final class ReminderGroupingSpec: QuickSpec {
    override class func spec() {
        describe("groupedByList") {
            context("single list") {
                it("returns one group with the correct header") {
                    let items = [
                        ReminderItem(title: "Buy milk", calendarTitle: "Shopping"),
                        ReminderItem(title: "Buy eggs", calendarTitle: "Shopping"),
                    ]
                    let groups = groupedByList(items, sortedBy: .title)
                    expect(groups.count) == 1
                    expect(groups[0].header) == "Shopping"
                }
                it("sorts items within the group by the given order") {
                    let items = [
                        ReminderItem(title: "Zucchini", calendarTitle: "Shopping"),
                        ReminderItem(title: "Apples", calendarTitle: "Shopping"),
                    ]
                    let groups = groupedByList(items, sortedBy: .title)
                    expect(groups[0].items.map(\.title)) == ["Apples", "Zucchini"]
                }
            }
            context("multiple lists") {
                it("returns groups sorted alphabetically by header") {
                    let items = [
                        ReminderItem(title: "Task A", calendarTitle: "Work"),
                        ReminderItem(title: "Task B", calendarTitle: "Personal"),
                        ReminderItem(title: "Task C", calendarTitle: "Home"),
                    ]
                    let groups = groupedByList(items, sortedBy: .title)
                    expect(groups.map(\.header)) == ["Home", "Personal", "Work"]
                }
                it("places each item in the correct group") {
                    let items = [
                        ReminderItem(title: "Task A", calendarTitle: "Work"),
                        ReminderItem(title: "Task B", calendarTitle: "Personal"),
                    ]
                    let groups = groupedByList(items, sortedBy: .title)
                    let personal = groups.first(where: { $0.header == "Personal" })
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
