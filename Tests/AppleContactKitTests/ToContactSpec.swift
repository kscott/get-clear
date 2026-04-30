// ToContactSpec.swift
//
// Tests for ContactKit toContact — CNContact to Contact conversion.

@testable import AppleContactKit
import ContactKit
import Contacts
import Nimble
import Quick

final class ToContactSpec: QuickSpec {
    override class func spec() {
        func makeContact(given: String = "", family: String = "",
                         org: String = "",
                         emails: [(String, String)] = [],
                         phones: [(String, String)] = []) -> CNMutableContact
        {
            let c = CNMutableContact()
            c.givenName = given
            c.familyName = family
            c.organizationName = org
            c.emailAddresses = emails.map { CNLabeledValue(label: $0.0, value: $0.1 as NSString) }
            c.phoneNumbers = phones.map { CNLabeledValue(label: $0.0, value: CNPhoneNumber(stringValue: $0.1)) }
            return c
        }

        describe("toContact") {
            context("identifier") {
                it("passes through the CNContact identifier") {
                    let c = makeContact(given: "Alice")
                    expect(toContact(c).identifier) == c.identifier
                }
            }

            context("name assembly") {
                it("joins given and family name with a space") {
                    let c = makeContact(given: "Alice", family: "Smith")
                    expect(toContact(c).name) == "Alice Smith"
                }
                it("uses given name alone when family is empty") {
                    let c = makeContact(given: "Alice")
                    expect(toContact(c).name) == "Alice"
                }
                it("uses family name alone when given is empty") {
                    let c = makeContact(family: "Smith")
                    expect(toContact(c).name) == "Smith"
                }
                it("produces empty name when both given and family are empty") {
                    let c = makeContact()
                    expect(toContact(c).name) == ""
                }
            }

            context("company") {
                it("maps organizationName to company") {
                    let c = makeContact(org: "Acme")
                    expect(toContact(c).company) == "Acme"
                }
                it("produces empty company when organizationName is empty") {
                    let c = makeContact()
                    expect(toContact(c).company) == ""
                }
            }

            context("emails") {
                it("maps email addresses to ContactFields") {
                    let c = makeContact(emails: [("_$!<Work>!$_", "alice@example.com")])
                    expect(toContact(c).emails) == [ContactField(label: "work", value: "alice@example.com")]
                }
                it("preserves multiple email addresses in order") {
                    let c = makeContact(emails: [("_$!<Work>!$_", "alice@work.com"),
                                                 ("_$!<Home>!$_", "alice@home.com")])
                    let emails = toContact(c).emails
                    expect(emails.count) == 2
                    expect(emails[0].value) == "alice@work.com"
                    expect(emails[1].value) == "alice@home.com"
                }
                it("produces empty emails when none are present") {
                    let c = makeContact()
                    expect(toContact(c).emails).to(beEmpty())
                }
                it("uses empty string for a nil label") {
                    let c = CNMutableContact()
                    c.emailAddresses = [CNLabeledValue(label: nil, value: "x@y.com" as NSString)]
                    expect(toContact(c).emails.first?.label) == ""
                }
            }

            context("phones") {
                it("maps phone numbers to ContactFields") {
                    let c = makeContact(phones: [("mobile", "+15551234567")])
                    expect(toContact(c).phones) == [ContactField(label: "mobile", value: "+15551234567")]
                }
                it("preserves multiple phone numbers in order") {
                    let c = makeContact(phones: [("mobile", "555-1111"), ("home", "555-2222")])
                    let phones = toContact(c).phones
                    expect(phones.count) == 2
                    expect(phones[0].value) == "555-1111"
                    expect(phones[1].value) == "555-2222"
                }
                it("produces empty phones when none are present") {
                    let c = makeContact()
                    expect(toContact(c).phones).to(beEmpty())
                }
            }
        }
    }
}
