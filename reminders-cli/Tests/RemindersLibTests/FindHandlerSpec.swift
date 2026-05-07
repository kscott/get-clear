// FindHandlerSpec.swift

import Foundation
import GetClearKit
import Nimble
import Quick
import RemindersLib

final class FindHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyStore!

        beforeEach { store = SpyStore() }

        describe("handleFind") {
            it("returns formatted find rows for matching items") {
                store.items = [makeItem()]
                let out = try await handleFind(args: ["find", "rent"], store: store)
                expect(out).to(contain("Pay rent"))
            }
            it("returns a no-match message when nothing matches") {
                store.items = [makeItem(title: "Buy groceries")]
                let out = try await handleFind(args: ["find", "dentist"], store: store)
                expect(out).to(contain("dentist"))
                expect(out).to(contain("No"))
            }
            it("throws when no query argument is provided") {
                await expect {
                    try await handleFind(args: ["find"], store: store)
                }.to(throwError(errorType: ReminderHandlerError.self))
            }
        }
    }
}
