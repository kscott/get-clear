// ContactDraftSpec.swift
//
// Tests for ContactKit ContactDraft — a new contact before it is saved.

import ContactKit
import Foundation
import Testing

private func roundTrip(_ draft: ContactDraft) throws -> ContactDraft {
    try JSONDecoder().decode(ContactDraft.self, from: JSONEncoder().encode(draft))
}

@Suite("ContactDraft coding")
struct ContactDraftCodingTests {
    @Test("a draft with every field set survives a JSON round trip")
    func everyField() throws {
        let draft = ContactDraft(name: "Bob Smith", emails: ["bob@x.com"], phones: ["555-1234"], company: "Acme")
        #expect(try roundTrip(draft) == draft)
    }

    @Test("a draft with only a name keeps its missing company as nil")
    func nameOnly() throws {
        #expect(try roundTrip(ContactDraft(name: "Bob Smith")).company == nil)
    }
}
