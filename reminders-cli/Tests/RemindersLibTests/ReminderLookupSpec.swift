// ReminderLookupSpec.swift
// Tests for lookup(title:in:) — exact case-insensitive match with disambiguation.

import Quick
import Nimble
import RemindersLib

final class ReminderLookupSpec: QuickSpec {
    override class func spec() {

        func makeItem(title: String, calendarTitle: String = "Test") -> ReminderItem {
            ReminderItem(title: title, calendarTitle: calendarTitle)
        }

        describe("lookup") {

            context("single match") {
                it("returns found with the correct index") {
                    let items = [makeItem(title: "Pay rent"), makeItem(title: "Buy groceries")]
                    expect(lookup(title: "Pay rent", in: items)) == .found(0)
                }
                it("returns found at a non-zero index") {
                    let items = [makeItem(title: "Buy groceries"), makeItem(title: "Pay rent")]
                    expect(lookup(title: "Pay rent", in: items)) == .found(1)
                }
                it("is case-insensitive") {
                    let items = [makeItem(title: "Pay Rent")]
                    expect(lookup(title: "pay rent", in: items)) == .found(0)
                }
                it("requires an exact match — does not match substrings") {
                    let items = [makeItem(title: "Pay rent this month")]
                    expect(lookup(title: "Pay rent", in: items)) == .notFound
                }
            }

            context("no match") {
                it("returns notFound when no title matches") {
                    let items = [makeItem(title: "Buy groceries")]
                    expect(lookup(title: "Pay rent", in: items)) == .notFound
                }
                it("returns notFound for empty array") {
                    expect(lookup(title: "Pay rent", in: [])) == .notFound
                }
            }

            context("multiple matches") {
                it("returns ambiguous with indices of all matching items") {
                    let items = [
                        makeItem(title: "Pay rent", calendarTitle: "Personal"),
                        makeItem(title: "Buy groceries"),
                        makeItem(title: "Pay rent", calendarTitle: "Work"),
                    ]
                    expect(lookup(title: "Pay rent", in: items)) == .ambiguous([0, 2])
                }
                it("is case-insensitive for ambiguous matches") {
                    let items = [
                        makeItem(title: "Pay Rent", calendarTitle: "Personal"),
                        makeItem(title: "PAY RENT", calendarTitle: "Work"),
                    ]
                    expect(lookup(title: "pay rent", in: items)) == .ambiguous([0, 1])
                }
            }
        }
    }
}
