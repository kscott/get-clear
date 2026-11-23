// ContactGroupSpec.swift
//
// Tests for ContactKit ContactGroup.

import ContactKit
import Foundation
import Testing

@Suite("ContactGroup coding")
struct ContactGroupCodingTests {
    @Test("a group survives a JSON round trip")
    func roundTrips() throws {
        let group = ContactGroup(identifier: "g-1", name: "Team Members")
        #expect(try JSONDecoder().decode(ContactGroup.self, from: JSONEncoder().encode(group)) == group)
    }
}
