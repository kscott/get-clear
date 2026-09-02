// SetupHandlerSpec.swift
// Tests for MailLib selectIdentityEmail.

import MailLib
import Testing

private let identities = [
    MailIdentity(id: "id1", email: "a@example.com", name: "Alice"),
    MailIdentity(id: "id2", email: "b@example.com", name: "Bob"),
    MailIdentity(id: "id3", email: "c@example.com", name: "Charlie")
]

@Suite("selectIdentityEmail")
struct SetupHandlerTests {
    @Test("returns the first identity for choice 1")
    func firstForChoice1() {
        #expect(selectIdentityEmail(from: identities, choice: 1) == "a@example.com")
    }

    @Test("returns the second identity for choice 2")
    func secondForChoice2() {
        #expect(selectIdentityEmail(from: identities, choice: 2) == "b@example.com")
    }

    @Test("returns the last identity for choice at the boundary")
    func lastForBoundaryChoice() {
        #expect(selectIdentityEmail(from: identities, choice: 3) == "c@example.com")
    }

    @Test("defaults to the first identity when choice is out of range high")
    func defaultsWhenHigh() {
        #expect(selectIdentityEmail(from: identities, choice: 99) == "a@example.com")
    }

    @Test("defaults to the first identity when choice is zero")
    func defaultsWhenZero() {
        #expect(selectIdentityEmail(from: identities, choice: 0) == "a@example.com")
    }

    @Test("defaults to the first identity when choice is negative")
    func defaultsWhenNegative() {
        #expect(selectIdentityEmail(from: identities, choice: -1) == "a@example.com")
    }

    @Test("returns empty string for an empty identity list")
    func emptyForEmptyList() {
        #expect(selectIdentityEmail(from: [], choice: 1) == "")
    }
}
