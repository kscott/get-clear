// ContactChangesSpec.swift
//
// Tests for ContactKit ContactChanges — the resolved set of field changes for a contact.

import ContactKit
import Foundation
import GetClearKit
import Testing

@Suite("ContactChanges")
struct ContactChangesTests {
    @Test("every field defaults to unchanged")
    func defaultsUnchanged() {
        #expect(ContactChanges() == ContactChanges(email: .unchanged, phone: .unchanged, company: .unchanged))
    }

    @Test("changes to every field survive a JSON round trip")
    func roundTrips() throws {
        let changes = ContactChanges(email: .added("a@x.com"), phone: .replaced(from: "1", to: "2"), company: .cleared)
        #expect(try JSONDecoder().decode(ContactChanges.self, from: JSONEncoder().encode(changes)) == changes)
    }
}
