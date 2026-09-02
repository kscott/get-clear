// SpyContactStoreSpec.swift
//
// Documents and verifies the SpyContactStore test double pattern for ContactStore.

import ContactKit
import ContactTestSupport
import Foundation
import Testing

@Suite("SpyContactStore")
struct SpyContactStoreTests {
    @Test("returns pre-loaded contacts via contacts()")
    func returnsPreloadedContacts() async {
        let spy = SpyContactStore()
        spy.contacts = [aliceContact]
        let fetched = await (try? spy.contacts()) ?? []
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Alice Smith")
    }

    @Test("returns an empty list when initialized with no contacts")
    func returnsEmptyListWhenUnloaded() async {
        let spy = SpyContactStore()
        let fetched = await (try? spy.contacts()) ?? []
        #expect(fetched.isEmpty)
    }

    @Test("records delete calls")
    func recordsDeleteCalls() async {
        let spy = SpyContactStore()
        try? await spy.delete(identifier: "alice-id")
        #expect(spy.deletedIds == ["alice-id"])
    }

    @Test("records rename calls")
    func recordsRenameCalls() async {
        let spy = SpyContactStore()
        try? await spy.rename(identifier: "alice-id", to: "Alice Jones")
        #expect(spy.renamedItems.first?.identifier == "alice-id")
        #expect(spy.renamedItems.first?.to == "Alice Jones")
    }
}
