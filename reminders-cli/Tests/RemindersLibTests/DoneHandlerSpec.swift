// DoneHandlerSpec.swift

import Foundation
import GetClearKit
import Nimble
import Quick
import RemindersLib

final class DoneHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyStore!

        beforeEach { store = SpyStore() }

        describe("handleDone") {
            it("returns Done: <title> on success") {
                store.items = [makeItem(identifier: "id-1")]
                let out = try await handleDone(args: ["done", "Pay rent"], store: store)
                expect(out) == "Done: Pay rent"
            }
            it("records the identifier with the store") {
                store.items = [makeItem(identifier: "id-1")]
                _ = try await handleDone(args: ["done", "Pay rent"], store: store)
                expect(store.completedIds) == ["id-1"]
            }
            it("throws the not-found message when the title is absent from the store") {
                store.items = []
                await expect {
                    try await handleDone(args: ["done", "Pay rent"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("Pay rent"))
                })
            }
            it("throws when no title argument is provided") {
                await expect {
                    try await handleDone(args: ["done"], store: store)
                }.to(throwError(errorType: ReminderHandlerError.self))
            }
        }
    }
}
