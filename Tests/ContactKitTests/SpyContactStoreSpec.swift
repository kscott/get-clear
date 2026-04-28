// SpyContactStoreSpec.swift
//
// Documents and verifies the SpyContactStore test double pattern for ContactStore.

import Quick
import Nimble
import Foundation
import ContactKit
import ContactTestSupport

final class SpyContactStoreSpec: QuickSpec {
    override class func spec() {
        describe("SpyContactStore") {
            it("returns pre-loaded contacts via contacts()") {
                let spy = SpyContactStore()
                spy.contacts = [aliceContact]
                var fetched: [Contact] = []
                waitUntil { done in
                    Task {
                        fetched = (try? await spy.contacts()) ?? []
                        done()
                    }
                }
                expect(fetched.count) == 1
                expect(fetched.first?.name) == "Alice Smith"
            }
            it("returns an empty list when initialized with no contacts") {
                let spy = SpyContactStore()
                var fetched: [Contact] = []
                waitUntil { done in
                    Task {
                        fetched = (try? await spy.contacts()) ?? []
                        done()
                    }
                }
                expect(fetched).to(beEmpty())
            }
            it("records delete calls") {
                let spy = SpyContactStore()
                waitUntil { done in
                    Task {
                        try? await spy.delete(identifier: "alice-id")
                        done()
                    }
                }
                expect(spy.deletedIds) == ["alice-id"]
            }
            it("records rename calls") {
                let spy = SpyContactStore()
                waitUntil { done in
                    Task {
                        try? await spy.rename(identifier: "alice-id", to: "Alice Jones")
                        done()
                    }
                }
                expect(spy.renamedItems.first?.identifier) == "alice-id"
                expect(spy.renamedItems.first?.to) == "Alice Jones"
            }
        }
    }
}
