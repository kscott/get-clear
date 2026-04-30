// ContactMatchingSpec.swift
//
// Tests for matchContacts — contact query matching and result ordering.

import ContactKit
import ContactTestSupport
import Foundation
import Nimble
import Quick

final class ContactMatchingSpec: QuickSpec {
    override class func spec() {
        let all = [aliceContact, bobContact, charlieContact, noEmailContact, orgOnlyContact]

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
                        makeContact(identifier: "jr-id", name: "Smith Jr"),
                        makeContact(identifier: "smith-id", name: "Smith"),
                        makeContact(identifier: "john-id", name: "John Smith")
                    ]
                    let r = matchContacts("smith", in: contacts)
                    expect(r[0].name) == "Smith"
                    expect(r[1].name) == "Smith Jr"
                    expect(r[2].name) == "John Smith"
                }
            }

            context("edge cases") {
                it("empty query returns an empty list") {
                    expect(matchContacts("", in: all)).to(beEmpty())
                }
                it("unmatched query returns empty") {
                    expect(matchContacts("xyzzy", in: all)).to(beEmpty())
                }
                it("matching is case insensitive") {
                    expect(matchContacts("ALICE", in: all)).toNot(beEmpty())
                }
            }

            context("identifier preservation") {
                it("returned contact carries the original identifier") {
                    expect(matchContacts("alice", in: all).first?.identifier) == "alice-id"
                }
            }
        }
    }
}
