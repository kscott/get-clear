// MatchingSpec.swift
//
// Tests for ContactsLib Matching — contact search, formatting, and export.

import Quick
import Nimble
import Foundation
import ContactsLib

final class MatchingSpec: QuickSpec {
    override class func spec() {
        let alice   = ContactRecord(name: "Alice Smith",   emails: [("work", "alice@example.com")],  phones: [("main", "555-1234")],      company: "Acme")
        let bob     = ContactRecord(name: "Bob Jones",     emails: [("work", "bob@jones.org")],       phones: [],                          company: "BJCO")
        let charlie = ContactRecord(name: "Charlie Brown", emails: [("home", "cbrown@peanuts.com")],  phones: [("main", "555-9999")],      company: "")
        let noEmail = ContactRecord(name: "Dana White",    emails: [],                                 phones: [("main", "303-555-0000")],  company: "")
        let orgOnly = ContactRecord(name: "",              emails: [("work", "info@initech.com")],    phones: [],                          company: "Initech")

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
                        ContactRecord(name: "Smith Jr",   emails: [], phones: [], company: ""),
                        ContactRecord(name: "Smith",      emails: [], phones: [], company: ""),
                        ContactRecord(name: "John Smith", emails: [], phones: [], company: ""),
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

        describe("ContactRecord") {
            context("primaryEmail") {
                it("returns the first email address") {
                    expect(alice.primaryEmail) == "alice@example.com"
                }
                it("returns empty string when no emails") {
                    expect(noEmail.primaryEmail) == ""
                }
                it("returns email for org-only record") {
                    expect(orgOnly.primaryEmail) == "info@initech.com"
                }
            }

            context("addressField") {
                it("formats as Name <email>") {
                    expect(alice.addressField) == "Alice Smith <alice@example.com>"
                }
                it("returns name only when no email") {
                    expect(noEmail.addressField) == "Dana White"
                }
            }
        }

        describe("exportAddresses") {
            it("includes contacts with email") {
                let result = exportAddresses([alice, bob, noEmail])
                expect(result).to(contain("Alice Smith <alice@example.com>"))
                expect(result).to(contain("Bob Jones <bob@jones.org>"))
            }
            it("excludes contacts without email") {
                expect(exportAddresses([alice, bob, noEmail])).toNot(contain("Dana White"))
            }
            it("separates entries with commas") {
                expect(exportAddresses([alice, bob])).to(contain(", "))
            }
            it("returns empty string for empty input") {
                expect(exportAddresses([])).to(beEmpty())
            }
            it("returns empty string when all contacts lack email") {
                expect(exportAddresses([noEmail])).to(beEmpty())
            }
        }

        describe("cleanLabel") {
            it("strips CNLabel prefix and suffix") {
                expect(cleanLabel("_$!<Work>!$_")) == "work"
            }
            it("lowercases plain label strings") {
                expect(cleanLabel("Mobile")) == "mobile"
            }
            it("passes through empty string unchanged") {
                expect(cleanLabel("")) == ""
            }
            it("lowercases without stripping when no prefix present") {
                expect(cleanLabel("iPhone")) == "iphone"
            }
        }
    }
}
