// RemoveHandlerSpec.swift

import Foundation
import GetClearKit
import Nimble
import Quick
import RemindersLib

final class RemoveHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyStore!

        beforeEach { store = SpyStore() }

        describe("handleRemove") {
            it("returns the removal confirmation") {
                store.items = [makeItem(identifier: "id-1")]
                let out = try await handleRemove(args: ["remove", "Pay rent"], store: store)
                expect(out).to(contain("Pay rent"))
            }
            it("records the deleted identifier with the store") {
                store.items = [makeItem(identifier: "id-1")]
                _ = try await handleRemove(args: ["remove", "Pay rent"], store: store)
                expect(store.deletedIds) == ["id-1"]
            }
            it("throws with the not-found message when the title is absent from the store") {
                store.items = []
                await expect {
                    try await handleRemove(args: ["remove", "Pay rent"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("Pay rent"))
                })
            }
            it("throws with the disambiguation message when the title is ambiguous") {
                store.items = ambiguousItems()
                await expect {
                    try await handleRemove(args: ["remove", "Pay rent"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("remove"))
                })
            }
            it("filters by the named list") {
                store.lists = [personalList, workList]
                store.items = [makeItem(identifier: "id-1")]
                _ = try await handleRemove(args: ["remove", "Pay rent", "Personal"], store: store)
                expect(store.deletedIds) == ["id-1"]
            }
            it("throws when the named list does not exist") {
                store.lists = [personalList]
                store.items = [makeItem(identifier: "id-1")]
                await expect {
                    try await handleRemove(args: ["remove", "Pay rent", "Nonexistent"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("Nonexistent"))
                })
            }
        }
    }
}
