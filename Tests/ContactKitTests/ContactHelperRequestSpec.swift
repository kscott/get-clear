// ContactHelperRequestSpec.swift
//
// Tests for ContactKit ContactHelperRequest — every case survives the wire.

import ContactKit
import Foundation
import Testing

private let team = ContactGroup(identifier: "g-1", name: "Team Members")

private let everyRequest: [ContactHelperRequest] = [
    .fetchGroups,
    .fetchContacts(group: team),
    .fetchContacts(group: nil),
    .add(ContactDraft(name: "Bob Smith", emails: ["bob@x.com"])),
    .addToGroup(identifier: "c-1", group: team),
    .removeFromGroup(identifier: "c-1", group: team),
    .update(identifier: "c-1", changes: ContactChanges(phone: .added("555-1234"))),
    .rename(identifier: "c-1", newName: "Robert Smith"),
    .delete(identifier: "c-1")
]

@Suite("ContactHelperRequest coding")
struct ContactHelperRequestTests {
    @Test("each request survives a JSON round trip", arguments: everyRequest)
    func roundTrips(request: ContactHelperRequest) throws {
        let decoded = try JSONDecoder().decode(ContactHelperRequest.self, from: JSONEncoder().encode(request))
        #expect(decoded == request)
    }
}
