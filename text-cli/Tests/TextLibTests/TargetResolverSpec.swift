// TargetResolverSpec.swift
// Tests for TextLib resolveTarget and requiresContactLookup.

import ContactKit
import Foundation
import Testing
import TextLib

private func phone(_ value: String) -> ContactField {
    ContactField(label: "mobile", value: value)
}

private func email(_ value: String) -> ContactField {
    ContactField(label: "home", value: value)
}

private func contact(_ name: String, phones: [ContactField] = [], emails: [ContactField] = []) -> Contact {
    Contact(identifier: "", name: name, emails: emails, phones: phones, company: "")
}

private let alice = contact("Alice Smith", phones: [phone("+15551234567")], emails: [email("alice@example.com")])
private let bob = contact("Bob Jones", phones: [phone("(555) 999-8888")])
private let charlie = contact("Charlie Brown", emails: [email("charlie@example.com")])
private let noAddr = contact("Dana White")
private let all = [alice, bob, charlie, noAddr]

@Suite("resolveTarget")
struct ResolveTargetTests {
    @Suite("direct phone number")
    struct DirectPhoneNumber {
        @Test("normalizes 10-digit number to E.164 address")
        func normalizesTenDigit() throws {
            #expect(try resolveTarget(query: "5551234567", contacts: []).address == "+15551234567")
        }

        @Test("uses formatted phone as display name")
        func formattedPhoneDisplayName() throws {
            #expect(try resolveTarget(query: "5551234567", contacts: []).displayName == "(555) 123-4567")
        }

        @Test("handles 11-digit number with country code")
        func handlesElevenDigit() throws {
            #expect(try resolveTarget(query: "15551234567", contacts: []).address == "+15551234567")
        }
    }

    @Suite("direct email address")
    struct DirectEmailAddress {
        @Test("passes email through as address")
        func emailAsAddress() throws {
            #expect(try resolveTarget(query: "user@example.com", contacts: []).address == "user@example.com")
        }

        @Test("uses email as display name")
        func emailAsDisplayName() throws {
            #expect(try resolveTarget(query: "user@example.com", contacts: []).displayName == "user@example.com")
        }
    }

    @Suite("name match — single result")
    struct NameMatchSingleResult {
        @Test("returns contact's normalized phone as address")
        func contactNormalizedPhone() throws {
            #expect(try resolveTarget(query: "Alice", contacts: all).address == "+15551234567")
        }

        @Test("returns contact's full name as display name")
        func contactFullName() throws {
            #expect(try resolveTarget(query: "Alice", contacts: all).displayName == "Alice Smith")
        }

        @Test("falls back to email when contact has no phone")
        func fallsBackToEmail() throws {
            #expect(try resolveTarget(query: "Charlie", contacts: all).address == "charlie@example.com")
        }
    }

    @Suite("not found")
    struct NotFound {
        @Test("throws notFound for an unknown name")
        func throwsForUnknownName() {
            #expect(throws: TextError.notFound("xyzzy")) {
                try resolveTarget(query: "xyzzy", contacts: all)
            }
        }

        @Test("throws notFound for a contact with no phone or email")
        func throwsForContactWithNoAddress() {
            #expect(throws: TextError.notFound("Dana")) {
                try resolveTarget(query: "Dana", contacts: all)
            }
        }
    }

    @Suite("ambiguous match")
    struct AmbiguousMatch {
        @Test("throws ambiguous when multiple contacts match")
        func throwsWhenMultipleMatch() {
            let c1 = contact("Alice Smith")
            let c2 = contact("Alice Jones")
            let expected = TextError.ambiguous(
                "\"Alice\" matches multiple contacts — be more specific:\n  Alice Smith\n  Alice Jones"
            )
            #expect(throws: expected) {
                try resolveTarget(query: "Alice", contacts: [c1, c2])
            }
        }
    }
}

@Suite("requiresContactLookup")
struct RequiresContactLookupTests {
    @Test("returns false for a 10-digit phone number")
    func falseForTenDigitPhone() {
        #expect(!requiresContactLookup("5551234567"))
    }

    @Test("returns false for an E.164 phone number")
    func falseForE164Phone() {
        #expect(!requiresContactLookup("+15551234567"))
    }

    @Test("returns false for an email address")
    func falseForEmail() {
        #expect(!requiresContactLookup("user@example.com"))
    }

    @Test("returns true for a name")
    func trueForName() {
        #expect(requiresContactLookup("Alice"))
    }
}
