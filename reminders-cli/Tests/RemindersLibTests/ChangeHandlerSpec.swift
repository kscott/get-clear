// ChangeHandlerSpec.swift

import Foundation
import GetClearKit
import Nimble
import Quick
import RemindersLib

final class ChangeHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyStore!

        beforeEach { store = SpyStore() }

        describe("handleChange") {
            it("returns the update confirmation with change descriptions") {
                store.items = [makeItem(identifier: "id-1")]
                let out = try await handleChange(args: ["change", "Pay rent", "priority", "high"], store: store)
                expect(out).to(contain("Pay rent"))
                expect(out).to(contain("high"))
            }
            it("records the update with the store") {
                store.items = [makeItem(identifier: "id-1")]
                _ = try await handleChange(args: ["change", "Pay rent", "priority", "high"], store: store)
                expect(store.updatedItems.count) == 1
                expect(store.updatedItems[0].id) == "id-1"
            }
            it("throws when no title argument is provided") {
                await expect {
                    try await handleChange(args: ["change"], store: store)
                }.to(throwError(errorType: ReminderHandlerError.self))
            }
            it("throws when there is nothing to change") {
                store.items = [makeItem(identifier: "id-1")]
                await expect {
                    try await handleChange(args: ["change", "Pay rent"], store: store)
                }.to(throwError(errorType: ReminderHandlerError.self))
            }
            it("throws with the not-found message when the title is absent from the store") {
                store.items = []
                await expect {
                    try await handleChange(args: ["change", "Pay rent", "priority", "high"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("Pay rent"))
                })
            }
            it("throws with the disambiguation message when the title is ambiguous") {
                store.items = ambiguousItems()
                await expect {
                    try await handleChange(args: ["change", "Pay rent", "priority", "high"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("change"))
                })
            }
            it("throws with unrecognized recurrence message") {
                store.items = [makeItem(identifier: "id-1")]
                await expect {
                    try await handleChange(args: ["change", "Pay rent", "repeat", "fortnightly"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("fortnightly"))
                })
            }
            it("carries existing item values as from in ValueChange") {
                store.items = [makeItem(identifier: "id-1", priority: 5, notes: "old note")]
                _ = try await handleChange(args: ["change", "Pay rent", "priority", "high"], store: store)
                let changes = store.updatedItems[0].changes
                expect(changes.priority) == .replaced(from: 5, to: 1)
                expect(changes.note) == .unchanged
            }
            it("produces added when existing optional field is nil") {
                store.items = [makeItem(identifier: "id-1")]
                _ = try await handleChange(args: ["change", "Pay rent", "note", "buy milk"], store: store)
                let changes = store.updatedItems[0].changes
                expect(changes.note) == .added("buy milk")
            }
            it("produces replaced when existing optional field is present") {
                store.items = [makeItem(identifier: "id-1", notes: "old note")]
                _ = try await handleChange(args: ["change", "Pay rent", "note", "new note"], store: store)
                let changes = store.updatedItems[0].changes
                expect(changes.note) == .replaced(from: "old note", to: "new note")
            }
        }
    }
}
