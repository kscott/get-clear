import ContactKit

// MARK: - Fixture contacts

public let aliceContact = makeContact(
    identifier: "alice-id",
    name: "Alice Smith",
    emails: [ContactField(label: "work", value: "alice@example.com")],
    phones: [ContactField(label: "main", value: "555-1234")],
    company: "Acme"
)
public let bobContact = makeContact(
    identifier: "bob-id",
    name: "Bob Jones",
    emails: [ContactField(label: "work", value: "bob@jones.org")],
    phones: [],
    company: "BJCO"
)
public let charlieContact = makeContact(
    identifier: "charlie-id",
    name: "Charlie Brown",
    emails: [ContactField(label: "home", value: "cbrown@peanuts.com")],
    phones: [ContactField(label: "main", value: "555-9999")],
    company: ""
)
public let noEmailContact = makeContact(
    identifier: "dana-id",
    name: "Dana White",
    emails: [],
    phones: [ContactField(label: "main", value: "303-555-0000")],
    company: ""
)
public let orgOnlyContact = makeContact(
    identifier: "initech-id",
    name: "",
    emails: [ContactField(label: "work", value: "info@initech.com")],
    phones: [],
    company: "Initech"
)

// MARK: - Factory

public func makeContact(
    identifier: String = "contact-id",
    name: String = "Test Contact",
    emails: [ContactField] = [],
    phones: [ContactField] = [],
    company: String = ""
) -> Contact {
    Contact(identifier: identifier, name: name, emails: emails, phones: phones, company: company)
}
