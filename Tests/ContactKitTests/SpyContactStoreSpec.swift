// SpyContactStoreSpec.swift
//
// Documents and verifies the SpyContactStore test double pattern for ContactStore.

import ContactKit
import ContactTestSupport
import Foundation
import Nimble
import Quick

final class SpyContactStoreSpec: AsyncSpec {
    override class func spec() {
        describe("SpyContactStore") {
            it("returns pre-loaded contacts via contacts()") {
                let spy = SpyContactStore()
                spy.contacts = [aliceContact]
                let fetched = await (try? spy.contacts()) ?? []
                expect(fetched.count) == 1
                expect(fetched.first?.name) == "Alice Smith"
            }
            it("returns an empty list when initialized with no contacts") {
                let spy = SpyContactStore()
                let fetched = await (try? spy.contacts()) ?? []
                expect(fetched).to(beEmpty())
            }
            it("records delete calls") {
                let spy = SpyContactStore()
                try? await spy.delete(identifier: "alice-id")
                expect(spy.deletedIds) == ["alice-id"]
            }
            it("records rename calls") {
                let spy = SpyContactStore()
                try? await spy.rename(identifier: "alice-id", to: "Alice Jones")
                expect(spy.renamedItems.first?.identifier) == "alice-id"
                expect(spy.renamedItems.first?.to) == "Alice Jones"
            }
        }
    }
}
