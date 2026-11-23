// ContactSpec.swift
//
// Tests for ContactKit Contact and ContactField — the shared contact record.

import ContactKit
import Foundation
import Testing

private func roundTrip<T: Codable>(_ value: T) throws -> T {
    try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
}

@Suite("Contact")
struct ContactTests {
    @Suite("displayName")
    struct DisplayName {
        @Test("is the person's name when there is one")
        func usesName() {
            let contact = Contact(identifier: "c", name: "Alice Chen", emails: [], phones: [], company: "Acme")
            #expect(contact.displayName == "Alice Chen")
        }

        @Test("falls back to the company for a company-only card")
        func fallsBackToCompany() {
            let contact = Contact(identifier: "c", name: "", emails: [], phones: [], company: "Acme")
            #expect(contact.displayName == "Acme")
        }
    }

    @Suite("coding")
    struct Coding {
        @Test("a contact with emails and phones survives a JSON round trip")
        func roundTrips() throws {
            let contact = Contact(
                identifier: "c-1",
                name: "Alice Chen",
                emails: [ContactField(label: "work", value: "alice@example.com")],
                phones: [ContactField(label: "mobile", value: "555-1234"), ContactField(label: "home", value: "555-9876")],
                company: "Acme"
            )
            #expect(try roundTrip(contact) == contact)
        }
    }
}
