// RemoteContactStoreSpec.swift
//
// Tests for ContactKit RemoteContactStore, wired to dispatchContactRequest and a
// SpyContactStore through a loopback transport — proving both sides agree on every store
// method, with no XPC involved.

import ContactKit
import ContactTestSupport
import Foundation
import GetClearKit
import Testing

private func remote(_ spy: SpyContactStore) -> RemoteContactStore {
    RemoteContactStore(transport: { await dispatchContactRequest($0.request, to: spy) }, appVersion: "1.4.0")
}

private let team = ContactGroup(identifier: "g-1", name: "Team Members")

@Suite("RemoteContactStore")
struct RemoteContactStoreTests {
    @Suite("reads")
    struct Reads {
        @Test("fetchGroups returns the helper store's groups")
        func fetchGroups() async throws {
            let spy = SpyContactStore()
            spy.groups = [team]
            #expect(try await remote(spy).fetchGroups() == [team])
        }

        @Test("fetchContacts returns the helper store's contacts")
        func fetchContacts() async throws {
            let spy = SpyContactStore()
            spy.contacts = [makeContact(name: "Alice Chen")]
            #expect(try await remote(spy).fetchContacts(in: team) == [makeContact(name: "Alice Chen")])
        }
    }

    @Suite("writes")
    struct Writes {
        @Test("add sends the draft to the helper store")
        func addSendsDraft() async throws {
            let spy = SpyContactStore()
            _ = try await remote(spy).add(ContactDraft(name: "Bob Smith"))
            #expect(spy.addedDrafts == [ContactDraft(name: "Bob Smith")])
        }

        @Test("add returns the contact the helper store created")
        func addReturnsContact() async throws {
            let spy = SpyContactStore()
            spy.addResult = makeContact(identifier: "new", name: "Bob Smith")
            #expect(try await remote(spy).add(ContactDraft(name: "Bob Smith")) == makeContact(identifier: "new", name: "Bob Smith"))
        }

        @Test("adding to a group delivers the contact and group")
        func addToGroup() async throws {
            let spy = SpyContactStore()
            try await remote(spy).add(identifier: "c-1", to: team)
            #expect(spy.addedToGroup.map { "\($0.identifier) \($0.group.name)" } == ["c-1 Team Members"])
        }

        @Test("removing from a group delivers the contact and group")
        func removeFromGroup() async throws {
            let spy = SpyContactStore()
            try await remote(spy).remove(identifier: "c-1", from: team)
            #expect(spy.removedFromGroup.map { "\($0.identifier) \($0.group.name)" } == ["c-1 Team Members"])
        }

        @Test("update delivers the identifier and changes")
        func update() async throws {
            let spy = SpyContactStore()
            let changes = ContactChanges(email: .replaced(from: "a@x.com", to: "b@x.com"))
            try await remote(spy).update(identifier: "c-1", changes: changes)
            #expect(spy.updatedItems.map { "\($0.identifier) \($0.changes == changes)" } == ["c-1 true"])
        }

        @Test("rename delivers the identifier and new name")
        func rename() async throws {
            let spy = SpyContactStore()
            try await remote(spy).rename(identifier: "c-1", to: "Robert Smith")
            #expect(spy.renamedItems.map { "\($0.identifier) \($0.to)" } == ["c-1 Robert Smith"])
        }

        @Test("delete delivers the identifier")
        func delete() async throws {
            let spy = SpyContactStore()
            try await remote(spy).delete(identifier: "c-1")
            #expect(spy.deletedIds == ["c-1"])
        }
    }

    @Suite("resolve over the helper")
    struct Resolve {
        @Test("a query that matches nothing throws the same typed not-found as a local store")
        func notFoundIsTyped() async {
            await #expect(throws: ContactStoreError.notFound("Zed")) {
                _ = try await remote(SpyContactStore()).resolve(query: "Zed")
            }
        }
    }
}
