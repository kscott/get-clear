// AddHandlerSpec.swift

import Foundation
import GetClearKit
import Nimble
import Quick
import RemindersLib

final class AddHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyStore!

        beforeEach { store = SpyStore() }

        describe("handleAdd") {
            it("returns the add confirmation including the list name") {
                store.lists = [personalList]
                let out = try await handleAdd(args: ["add", "Pay rent", "Personal"], store: store)
                expect(out).to(contain("Pay rent"))
                expect(out).to(contain("Personal"))
            }
            it("records the added item with the store") {
                store.lists = [personalList]
                _ = try await handleAdd(args: ["add", "Pay rent", "Personal"], store: store)
                expect(store.addedItems.count) == 1
                expect(store.addedItems[0].title) == "Pay rent"
            }
            it("uses the default list when no list is specified") {
                store.lists = [personalList]
                _ = try await handleAdd(args: ["add", "Pay rent"], store: store)
                expect(store.addedItems[0].list.title) == "Personal"
            }
            it("sets the due date when a date option is provided") {
                store.lists = [personalList]
                _ = try await handleAdd(args: ["add", "Pay rent", "Personal", "due", "friday"], store: store)
                expect(store.addedItems[0].dueDateComponents).notTo(beNil())
            }
            it("sets the recurrence when a repeat option is provided") {
                store.lists = [personalList]
                _ = try await handleAdd(args: ["add", "Pay rent", "Personal", "repeat", "monthly"], store: store)
                expect(store.addedItems[0].recurrenceSpec).notTo(beNil())
            }
            it("throws with an unrecognized repeat message when the recurrence string is invalid") {
                store.lists = [personalList]
                await expect {
                    try await handleAdd(args: ["add", "Pay rent", "Personal", "repeat", "fortnightly"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("fortnightly"))
                })
            }
            it("throws when no title argument is provided") {
                await expect {
                    try await handleAdd(args: ["add"], store: store)
                }.to(throwError(errorType: ReminderHandlerError.self))
            }
        }
    }
}
