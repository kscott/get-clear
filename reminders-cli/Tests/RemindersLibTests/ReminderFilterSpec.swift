// ReminderFilterSpec.swift
// Tests for filtered(_:matching:) and matchesQuery(_:query:) — find command filtering.

import Quick
import Nimble
import RemindersLib

final class ReminderFilterSpec: QuickSpec {
    override class func spec() {

        describe("filtered") {

            context("title matching") {
                it("returns items whose title contains the query") {
                    let items = [makeItem(title: "Pay rent"), makeItem(title: "Buy groceries")]
                    expect(filtered(items, matching: "rent")).to(haveCount(1))
                    expect(filtered(items, matching: "rent")[0].title) == "Pay rent"
                }
                it("is case-insensitive") {
                    let items = [makeItem(title: "Pay Rent")]
                    expect(filtered(items, matching: "RENT")).to(haveCount(1))
                }
                it("matches partial titles") {
                    let items = [makeItem(title: "Schedule dentist appointment")]
                    expect(filtered(items, matching: "dentist")).to(haveCount(1))
                }
                it("returns multiple results when several titles match") {
                    let items = [makeItem(title: "Pay rent"), makeItem(title: "Review rent agreement"), makeItem(title: "Buy groceries")]
                    expect(filtered(items, matching: "rent")).to(haveCount(2))
                }
            }

            context("notes matching") {
                it("returns items whose notes contain the query") {
                    let items = [makeItem(title: "Task", notes: "remember to call Alice")]
                    expect(filtered(items, matching: "call Alice")).to(haveCount(1))
                }
                it("matches notes case-insensitively") {
                    let items = [makeItem(title: "Task", notes: "URGENT")]
                    expect(filtered(items, matching: "urgent")).to(haveCount(1))
                }
                it("matches items where title does not match but notes do") {
                    let items = [makeItem(title: "Unrelated", notes: "mention of dentist")]
                    expect(filtered(items, matching: "dentist")).to(haveCount(1))
                }
            }

            context("no match") {
                it("returns empty array when no items match") {
                    let items = [makeItem(title: "Pay rent"), makeItem(title: "Buy groceries")]
                    expect(filtered(items, matching: "dentist")).to(beEmpty())
                }
                it("returns empty array for empty input") {
                    expect(filtered([], matching: "anything")).to(beEmpty())
                }
            }
        }

        describe("matchesQuery") {
            it("returns true when title contains query") {
                expect(matchesQuery(makeItem(title: "Pay rent"), query: "rent")) == true
            }
            it("returns true when notes contain query") {
                expect(matchesQuery(makeItem(title: "Task", notes: "call Alice"), query: "Alice")) == true
            }
            it("returns false when neither title nor notes contain query") {
                expect(matchesQuery(makeItem(title: "Buy groceries"), query: "dentist")) == false
            }
            it("returns false when notes is nil and title does not match") {
                expect(matchesQuery(makeItem(title: "Buy groceries"), query: "dentist")) == false
            }
        }
    }
}
