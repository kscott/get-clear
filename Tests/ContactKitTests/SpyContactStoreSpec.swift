// SpyContactStoreSpec.swift
//
// Documents and verifies the SpyContactStore test double pattern for ContactStore.

import Quick
import Nimble
import Foundation
import GetClearKit

private struct SpyContactStore: ContactStore {
    let result: [Contact]
    func contacts() async throws -> [Contact] { result }
}

final class SpyContactStoreSpec: QuickSpec {
    override class func spec() {
        describe("SpyContactStore") {
            it("returns the pre-loaded contacts") {
                let alice = Contact(name: "Alice Smith",
                                   emails: [ContactField(label: "work", value: "alice@example.com")],
                                   phones: [],
                                   company: "")
                let spy = SpyContactStore(result: [alice])
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
                let spy = SpyContactStore(result: [])
                var fetched: [Contact] = []
                waitUntil { done in
                    Task {
                        fetched = (try? await spy.contacts()) ?? []
                        done()
                    }
                }
                expect(fetched).to(beEmpty())
            }
        }
    }
}
