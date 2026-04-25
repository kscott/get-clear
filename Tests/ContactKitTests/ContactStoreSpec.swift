// ContactStoreSpec.swift
//
// Tests for GetClearKit matchContacts — contact query matching and result ordering.

import Quick
import Nimble
import Foundation
import ContactKit

final class ContactStoreSpec: QuickSpec {
    override class func spec() {
        let alice   = Contact(name: "Alice Smith",
                              emails: [ContactField(label: "work", value: "alice@example.com")],
                              phones: [ContactField(label: "main", value: "555-1234")],
                              company: "Acme")
        let bob     = Contact(name: "Bob Jones",
                              emails: [ContactField(label: "work", value: "bob@jones.org")],
                              phones: [],
                              company: "BJCO")
        let charlie = Contact(name: "Charlie Brown",
                              emails: [ContactField(label: "home", value: "cbrown@peanuts.com")],
                              phones: [ContactField(label: "main", value: "555-9999")],
                              company: "")
        let noEmail = Contact(name: "Dana White",
                              emails: [],
                              phones: [ContactField(label: "main", value: "303-555-0000")],
                              company: "")
        let orgOnly = Contact(name: "",
                              emails: [ContactField(label: "work", value: "info@initech.com")],
                              phones: [],
                              company: "Initech")

        let all = [alice, bob, charlie, noEmail, orgOnly]

        describe("matchContacts") {
            context("name matching") {
                it("finds a contact by partial name") {
                    expect(matchContacts("alice", in: all).contains { $0.name == "Alice Smith" }) == true
                }
                it("returns only the matching contact for a unique query") {
                    expect(matchContacts("alice", in: all).count) == 1
                }
                it("exact prefix scores first") {
                    expect(matchContacts("alice", in: all).first?.name) == "Alice Smith"
                }
                it("finds a contact by last name") {
                    expect(matchContacts("brown", in: all).contains { $0.name == "Charlie Brown" }) == true
                }
                it("exact full name scores first") {
                    expect(matchContacts("Alice Smith", in: all).first?.name) == "Alice Smith"
                }
            }

            context("email matching") {
                it("finds a contact by email domain") {
                    expect(matchContacts("jones.org", in: all).contains { $0.name == "Bob Jones" }) == true
                }
            }

            context("company matching") {
                it("finds a contact by exact company name") {
                    expect(matchContacts("acme", in: all).contains { $0.name == "Alice Smith" }) == true
                }
                it("finds a contact by partial company name") {
                    expect(matchContacts("init", in: all).contains { $0.company == "Initech" }) == true
                }
            }

            context("phone matching") {
                it("finds a contact by digit string") {
                    expect(matchContacts("5559999", in: all).contains { $0.name == "Charlie Brown" }) == true
                }
                it("normalizes dashes in query") {
                    expect(matchContacts("555-9999", in: all).contains { $0.name == "Charlie Brown" }) == true
                }
            }

            context("sort order") {
                it("sorts exact name before prefix before substring") {
                    let contacts = [
                        Contact(name: "Smith Jr",   emails: [], phones: [], company: ""),
                        Contact(name: "Smith",      emails: [], phones: [], company: ""),
                        Contact(name: "John Smith", emails: [], phones: [], company: ""),
                    ]
                    let r = matchContacts("smith", in: contacts)
                    expect(r[0].name) == "Smith"
                    expect(r[1].name) == "Smith Jr"
                    expect(r[2].name) == "John Smith"
                }
            }

            context("edge cases") {
                it("empty query returns all contacts") {
                    expect(matchContacts("", in: all).count) == all.count
                }
                it("unmatched query returns empty") {
                    expect(matchContacts("xyzzy", in: all)).to(beEmpty())
                }
                it("matching is case insensitive") {
                    expect(matchContacts("ALICE", in: all)).toNot(beEmpty())
                }
            }
        }
    }
}
