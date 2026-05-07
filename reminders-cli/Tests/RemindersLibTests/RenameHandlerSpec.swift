// RenameHandlerSpec.swift

import Foundation
import GetClearKit
import Nimble
import Quick
import RemindersLib

final class RenameHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyStore!

        beforeEach { store = SpyStore() }

        describe("handleRename") {
            it("returns the rename confirmation") {
                store.items = [makeItem(identifier: "id-1")]
                let out = try await handleRename(args: ["rename", "Pay rent", "Pay mortgage"], store: store)
                expect(out).to(contain("Pay rent"))
                expect(out).to(contain("Pay mortgage"))
            }
            it("records the new title with the store") {
                store.items = [makeItem(identifier: "id-1")]
                _ = try await handleRename(args: ["rename", "Pay rent", "Pay mortgage"], store: store)
                expect(store.renamedItems.count) == 1
                expect(store.renamedItems[0].id) == "id-1"
                expect(store.renamedItems[0].to) == "Pay mortgage"
            }
            it("throws when fewer than 2 title arguments are provided") {
                await expect {
                    try await handleRename(args: ["rename", "Pay rent"], store: store)
                }.to(throwError(errorType: ReminderHandlerError.self))
            }
            it("throws with the not-found message when the title is absent from the store") {
                store.items = []
                await expect {
                    try await handleRename(args: ["rename", "Pay rent", "Pay mortgage"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("Pay rent"))
                })
            }
            it("throws with the disambiguation message when the title is ambiguous") {
                store.items = ambiguousItems()
                await expect {
                    try await handleRename(args: ["rename", "Pay rent", "Pay mortgage"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("rename"))
                })
            }
        }
    }
}
