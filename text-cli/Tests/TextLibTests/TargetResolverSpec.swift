// TargetResolverSpec.swift
// Tests for TextLib resolveTarget and requiresContactLookup.

import ContactKit
import Foundation
import Nimble
import Quick
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

final class TargetResolverSpec: QuickSpec {
    override class func spec() {
        let alice = contact("Alice Smith", phones: [phone("+15551234567")], emails: [email("alice@example.com")])
        let bob = contact("Bob Jones", phones: [phone("(555) 999-8888")])
        let charlie = contact("Charlie Brown", emails: [email("charlie@example.com")])
        let noAddr = contact("Dana White")
        let all = [alice, bob, charlie, noAddr]

        describe("resolveTarget") {
            context("direct phone number") {
                it("normalizes 10-digit number to E.164 address") {
                    expect(try! resolveTarget(query: "5551234567", contacts: []).address) == "+15551234567"
                }
                it("uses formatted phone as display name") {
                    expect(try! resolveTarget(query: "5551234567", contacts: []).displayName) == "(555) 123-4567"
                }
                it("handles 11-digit number with country code") {
                    expect(try! resolveTarget(query: "15551234567", contacts: []).address) == "+15551234567"
                }
            }

            context("direct email address") {
                it("passes email through as address") {
                    expect(try! resolveTarget(query: "user@example.com", contacts: []).address) == "user@example.com"
                }
                it("uses email as display name") {
                    expect(try! resolveTarget(query: "user@example.com", contacts: []).displayName) == "user@example.com"
                }
            }

            context("name match — single result") {
                it("returns contact's normalized phone as address") {
                    expect(try! resolveTarget(query: "Alice", contacts: all).address) == "+15551234567"
                }
                it("returns contact's full name as display name") {
                    expect(try! resolveTarget(query: "Alice", contacts: all).displayName) == "Alice Smith"
                }
                it("falls back to email when contact has no phone") {
                    expect(try! resolveTarget(query: "Charlie", contacts: all).address) == "charlie@example.com"
                }
            }

            context("not found") {
                it("throws notFound for an unknown name") {
                    expect { try resolveTarget(query: "xyzzy", contacts: all) }
                        .to(throwError(TextError.notFound("xyzzy")))
                }
                it("throws notFound for a contact with no phone or email") {
                    expect { try resolveTarget(query: "Dana", contacts: all) }
                        .to(throwError(TextError.notFound("Dana")))
                }
            }

            context("ambiguous match") {
                it("throws ambiguous when multiple contacts match") {
                    let c1 = contact("Alice Smith")
                    let c2 = contact("Alice Jones")
                    let expected = TextError.ambiguous(
                        "\"Alice\" matches multiple contacts — be more specific:\n  Alice Smith\n  Alice Jones"
                    )
                    expect { try resolveTarget(query: "Alice", contacts: [c1, c2]) }
                        .to(throwError(expected))
                }
            }
        }

        describe("requiresContactLookup") {
            it("returns false for a 10-digit phone number") {
                expect(requiresContactLookup("5551234567")) == false
            }
            it("returns false for an E.164 phone number") {
                expect(requiresContactLookup("+15551234567")) == false
            }
            it("returns false for an email address") {
                expect(requiresContactLookup("user@example.com")) == false
            }
            it("returns true for a name") {
                expect(requiresContactLookup("Alice")) == true
            }
        }
    }
}
