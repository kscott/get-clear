// ListsHandlerSpec.swift

import Foundation
import GetClearKit
import Nimble
import Quick
import RemindersLib

final class ListsHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyStore!

        beforeEach { store = SpyStore() }

        describe("handleLists") {
            it("returns newline-separated sorted list titles") {
                store.lists = [workList, personalList]
                let out = try await handleLists(store: store)
                expect(out) == "Personal\nWork"
            }
            it("returns empty string when there are no lists") {
                store.lists = []
                let out = try await handleLists(store: store)
                expect(out) == ""
            }
        }
    }
}
