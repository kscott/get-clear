// ReminderStoreSpec.swift
// Tests for ReminderStore.resolve — the default protocol extension for single-item lookup.

import Quick
import Nimble
import Foundation
import RemindersLib

// MARK: - Mock

private final class MockStore: ReminderStore {
    var lists: [ReminderList] = []
    var items: [ReminderItem] = []

    func fetchLists() async throws -> [ReminderList]                              { lists }
    func defaultList() async throws -> ReminderList                               { lists.first ?? ReminderList(title: "Reminders") }
    func fetchIncomplete(in list: ReminderList?) async throws -> [ReminderItem]   { items }
    func add(_ item: ReminderItem) async throws -> ReminderItem                   { item }
    func update(identifier: String, changes: ReminderChanges) async throws        {}
    func complete(identifier: String) async throws                                {}
    func rename(identifier: String, to title: String) async throws                {}
    func delete(identifier: String) async throws                                  {}
}

// MARK: - Spec

final class ReminderStoreSpec: AsyncSpec {
    override class func spec() {

        var store: MockStore!

        beforeEach { store = MockStore() }

        describe("resolve") {

            context("single match") {
                it("returns the matched item") {
                    store.items = [makeItem()]
                    let result = try await store.resolve(title: "Pay rent", in: nil)
                    expect(result.title) == "Pay rent"
                }
                it("is case-insensitive") {
                    store.items = [makeItem(title: "Pay Rent")]
                    let result = try await store.resolve(title: "pay rent", in: nil)
                    expect(result.title) == "Pay Rent"
                }
                it("passes the list filter through to fetchIncomplete") {
                    store.items = [makeItem()]
                    let result = try await store.resolve(title: "Pay rent", in: personalList)
                    expect(result.title) == "Pay rent"
                }
            }

            context("no match") {
                it("throws ReminderStoreError.notFound") {
                    store.items = []
                    await expect {
                        try await store.resolve(title: "Pay rent", in: nil)
                    }.to(throwError(ReminderStoreError.notFound("Pay rent")))
                }
            }

            context("multiple matches") {
                it("throws ReminderStoreError.ambiguous with all matches") {
                    store.items = [makeItem(), makeItem(list: workList)]
                    await expect {
                        try await store.resolve(title: "Pay rent", in: nil)
                    }.to(throwError { (err: ReminderStoreError) in
                        if case .ambiguous(let matches) = err {
                            expect(matches).to(haveCount(2))
                        } else {
                            fail("expected .ambiguous, got \(err)")
                        }
                    })
                }
            }
        }
    }
}
