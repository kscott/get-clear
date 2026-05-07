// ShowHandlerSpec.swift

import Foundation
import GetClearKit
import Nimble
import Quick
import RemindersLib

final class ShowHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyStore!

        beforeEach { store = SpyStore() }

        describe("handleShow") {
            it("returns the formatted show output for the matched item") {
                store.items = [makeItem()]
                let out = try await handleShow(args: ["show", "Pay rent"], store: store)
                expect(out).to(contain("Pay rent"))
                expect(out).to(contain("Personal"))
            }
            it("throws with the not-found message when the title is absent") {
                store.items = []
                await expect {
                    try await handleShow(args: ["show", "Pay rent"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("Pay rent"))
                })
            }
            it("throws when no title argument is provided") {
                await expect {
                    try await handleShow(args: ["show"], store: store)
                }.to(throwError(errorType: ReminderHandlerError.self))
            }
        }
    }
}
