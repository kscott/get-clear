// ContactStoreSpec.swift
//
// Tests for ContactKit ContactStore.swift — ContactStoreError's wording and coding.
// The store extension helpers (resolve, resolveGroup) are covered through SpyContactStoreSpec.

import ContactKit
import Foundation
import Testing

private func roundTrip(_ error: ContactStoreError) throws -> ContactStoreError {
    try JSONDecoder().decode(ContactStoreError.self, from: JSONEncoder().encode(error))
}

private let alice = Contact(identifier: "a", name: "Alice Chen", emails: [], phones: [], company: "")
private let alex = Contact(identifier: "b", name: "Alex Chen", emails: [], phones: [], company: "")

@Suite("ContactStoreError")
struct ContactStoreErrorTests {
    @Suite("description")
    struct Description {
        @Test("not-found names the query")
        func notFound() {
            #expect(ContactStoreError.notFound("Bob").localizedDescription == "No contact found matching 'Bob'")
        }

        @Test("ambiguous lists every match by display name")
        func ambiguous() {
            #expect(ContactStoreError.ambiguous([alice, alex]).localizedDescription
                == "Multiple contacts match — Alice Chen, Alex Chen")
        }

        @Test("group-not-found names the group")
        func groupNotFound() {
            #expect(ContactStoreError.groupNotFound("Team").localizedDescription == "No group named 'Team'")
        }

        @Test("conflict says the contact may have changed elsewhere")
        func conflict() {
            #expect(ContactStoreError.conflict.localizedDescription
                == "Could not save — contact may have been modified in another app")
        }
    }

    @Suite("coding")
    struct Coding {
        @Test("ambiguous keeps its matches through a JSON round trip")
        func ambiguous() throws {
            #expect(try roundTrip(.ambiguous([alice, alex])) == .ambiguous([alice, alex]))
        }

        @Test("group-not-found keeps its name through a JSON round trip")
        func groupNotFound() throws {
            #expect(try roundTrip(.groupNotFound("Team")) == .groupNotFound("Team"))
        }

        @Test("conflict survives a JSON round trip")
        func conflict() throws {
            #expect(try roundTrip(.conflict) == .conflict)
        }
    }
}
