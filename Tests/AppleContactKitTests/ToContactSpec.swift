// ToContactSpec.swift
//
// Tests for ContactKit toContact — CNContact to Contact conversion.

@testable import AppleContactKit
import ContactKit
import Contacts
import Testing

private func makeContact(given: String = "", family: String = "",
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

@Suite("toContact")
struct ToContactTests {
    @Suite("identifier")
    struct Identifier {
        @Test("passes through the CNContact identifier")
        func passesThroughIdentifier() {
            let c = makeContact(given: "Alice")
            #expect(toContact(c).identifier == c.identifier)
        }
    }

    @Suite("name assembly")
    struct NameAssembly {
        @Test("joins given and family name with a space")
        func joinsGivenAndFamily() {
            let c = makeContact(given: "Alice", family: "Smith")
            #expect(toContact(c).name == "Alice Smith")
        }

        @Test("uses given name alone when family is empty")
        func givenAloneWhenFamilyEmpty() {
            let c = makeContact(given: "Alice")
            #expect(toContact(c).name == "Alice")
        }

        @Test("uses family name alone when given is empty")
        func familyAloneWhenGivenEmpty() {
            let c = makeContact(family: "Smith")
            #expect(toContact(c).name == "Smith")
        }

        @Test("produces empty name when both given and family are empty")
        func emptyNameWhenBothEmpty() {
            let c = makeContact()
            #expect(toContact(c).name == "")
        }
    }

    @Suite("company")
    struct Company {
        @Test("maps organizationName to company")
        func mapsOrganizationName() {
            let c = makeContact(org: "Acme")
            #expect(toContact(c).company == "Acme")
        }

        @Test("produces empty company when organizationName is empty")
        func emptyCompanyWhenOrgEmpty() {
            let c = makeContact()
            #expect(toContact(c).company == "")
        }
    }

    @Suite("emails")
    struct Emails {
        @Test("maps email addresses to ContactFields")
        func mapsEmailAddresses() {
            let c = makeContact(emails: [("_$!<Work>!$_", "alice@example.com")])
            #expect(toContact(c).emails == [ContactField(label: "work", value: "alice@example.com")])
        }

        @Test("preserves multiple email addresses in order")
        func preservesEmailOrder() {
            let c = makeContact(emails: [("_$!<Work>!$_", "alice@work.com"),
                                         ("_$!<Home>!$_", "alice@home.com")])
            let emails = toContact(c).emails
            #expect(emails.count == 2)
            #expect(emails[0].value == "alice@work.com")
            #expect(emails[1].value == "alice@home.com")
        }

        @Test("produces empty emails when none are present")
        func emptyEmailsWhenNone() {
            let c = makeContact()
            #expect(toContact(c).emails.isEmpty)
        }

        @Test("uses empty string for a nil label")
        func emptyStringForNilLabel() {
            let c = CNMutableContact()
            c.emailAddresses = [CNLabeledValue(label: nil, value: "x@y.com" as NSString)]
            #expect(toContact(c).emails.first?.label == "")
        }
    }

    @Suite("phones")
    struct Phones {
        @Test("maps phone numbers to ContactFields")
        func mapsPhoneNumbers() {
            let c = makeContact(phones: [("mobile", "+15551234567")])
            #expect(toContact(c).phones == [ContactField(label: "mobile", value: "+15551234567")])
        }

        @Test("preserves multiple phone numbers in order")
        func preservesPhoneOrder() {
            let c = makeContact(phones: [("mobile", "555-1111"), ("home", "555-2222")])
            let phones = toContact(c).phones
            #expect(phones.count == 2)
            #expect(phones[0].value == "555-1111")
            #expect(phones[1].value == "555-2222")
        }

        @Test("produces empty phones when none are present")
        func emptyPhonesWhenNone() {
            let c = makeContact()
            #expect(toContact(c).phones.isEmpty)
        }
    }
}
