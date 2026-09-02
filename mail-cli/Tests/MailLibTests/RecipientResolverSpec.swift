// RecipientResolverSpec.swift
// Tests for MailLib RecipientResolver — recipient resolution and address formatting.

import ContactKit
import ContactTestSupport
import Foundation
import MailLib
import Testing

private let alice = makeContact(
    identifier: "alice-id", name: "Alice Smith",
    emails: [ContactField(label: "work", value: "alice@example.com"),
             ContactField(label: "personal", value: "alice@work.com")],
    phones: []
)
private let bob = makeContact(
    identifier: "bob-id", name: "Bob Jones",
    emails: [ContactField(label: "work", value: "bob@jones.org")],
    phones: []
)
private let charlie = makeContact(
    identifier: "charlie-id", name: "Charlie Brown",
    emails: [ContactField(label: "home", value: "cbrown@peanuts.com")],
    phones: []
)
private let noEmail = makeContact(identifier: "dana-id", name: "Dana White", emails: [], phones: [])

private let contacts = [alice, bob, charlie, noEmail]

private let groups: [String: [AddressEntry]] = [
    "Board": [
        AddressEntry(name: "Alice Smith", email: "alice@example.com"),
        AddressEntry(name: "Bob Jones", email: "bob@jones.org")
    ]
]

@Suite("resolveRecipients")
struct ResolveRecipientsTests {
    @Suite("group name")
    struct GroupName {
        @Test("returns all members of a matching group")
        func returnsAllMembers() {
            #expect(resolveRecipients("Board", groups: groups, contacts: contacts).count == 2)
        }

        @Test("matches group name case-insensitively")
        func matchesCaseInsensitively() {
            #expect(resolveRecipients("board", groups: groups, contacts: contacts).count == 2)
        }

        @Test("returns members in order")
        func returnsMembersInOrder() {
            #expect(resolveRecipients("Board", groups: groups, contacts: contacts).first?.name == "Alice Smith")
        }
    }

    @Suite("contact name")
    struct ContactName {
        @Test("finds a contact by exact name")
        func findsByExactName() {
            #expect(resolveRecipients("Alice Smith", groups: groups, contacts: contacts).count == 1)
        }

        @Test("uses the primary email for a named contact")
        func usesPrimaryEmail() {
            #expect(resolveRecipients("Alice Smith", groups: groups, contacts: contacts).first?.email == "alice@example.com")
        }

        @Test("finds a contact by partial name")
        func findsByPartialName() {
            #expect(resolveRecipients("alice", groups: groups, contacts: contacts).first?.name == "Alice Smith")
        }
    }

    @Suite("email fragment")
    struct EmailFragment {
        @Test("finds a contact by email domain")
        func findsByEmailDomain() {
            #expect(resolveRecipients("jones.org", groups: groups, contacts: contacts).first?.name == "Bob Jones")
        }
    }

    @Suite("raw email address")
    struct RawEmailAddress {
        @Test("returns the address directly when it contains @")
        func returnsAddressDirectly() {
            let r = resolveRecipients("new@person.com", groups: groups, contacts: contacts)
            #expect(r.first?.email == "new@person.com")
        }

        @Test("leaves name empty for an unknown raw address")
        func leavesNameEmpty() {
            #expect(resolveRecipients("new@person.com", groups: groups, contacts: contacts).first?.name == "")
        }
    }

    @Suite("non-primary email")
    struct NonPrimaryEmail {
        @Test("preserves the exact address when a non-primary email is specified")
        func preservesExactAddress() {
            let r = resolveRecipients("alice@work.com", groups: groups, contacts: contacts)
            #expect(r.first?.email == "alice@work.com")
        }

        @Test("resolves the contact name from the non-primary email")
        func resolvesContactName() {
            let r = resolveRecipients("alice@work.com", groups: groups, contacts: contacts)
            #expect(r.first?.name == "Alice Smith")
        }
    }

    @Suite("no match")
    struct NoMatch {
        @Test("returns empty for an unknown query")
        func emptyForUnknownQuery() {
            #expect(resolveRecipients("xyzzy", groups: groups, contacts: contacts).isEmpty)
        }

        @Test("returns empty for a contact with no email")
        func emptyForContactWithNoEmail() {
            #expect(resolveRecipients("Dana", groups: groups, contacts: contacts).isEmpty)
        }
    }
}

@Suite("buildRecipients")
struct BuildRecipientsTests {
    @Suite("to field")
    struct ToField {
        @Test("resolves a single to recipient")
        func resolvesSingleTo() {
            let (to, _) = buildRecipients(to: ["alice@work.com"], cc: [], groups: groups, contacts: contacts)
            #expect(to.first?.email == "alice@work.com")
        }

        @Test("resolves the contact name for the to field")
        func resolvesToContactName() {
            let (to, _) = buildRecipients(to: ["alice@work.com"], cc: [], groups: groups, contacts: contacts)
            #expect(to.first?.name == "Alice Smith")
        }

        @Test("expands multiple to recipients")
        func expandsMultipleTo() {
            let (to, _) = buildRecipients(to: ["Alice Smith", "bob@jones.org"], cc: [],
                                          groups: groups, contacts: contacts)
            #expect(to.count == 2)
        }
    }

    @Suite("cc field")
    struct CcField {
        @Test("resolves a cc recipient")
        func resolvesCc() {
            let (_, cc) = buildRecipients(to: ["bob"], cc: ["alice@work.com"],
                                          groups: groups, contacts: contacts)
            #expect(cc.first?.email == "alice@work.com")
        }

        @Test("resolves multiple cc entries")
        func resolvesMultipleCc() {
            let (_, cc) = buildRecipients(to: ["bob"], cc: ["alice@work.com", "cbrown@peanuts.com"],
                                          groups: groups, contacts: contacts)
            #expect(cc.count == 2)
        }
    }

    @Suite("resolution consistency")
    struct ResolutionConsistency {
        @Test("cc resolves identically to a direct resolveRecipients call")
        func ccResolvesIdentically() {
            let direct = resolveRecipients("alice@work.com", groups: groups, contacts: contacts)
            let (_, cc) = buildRecipients(to: ["bob"], cc: ["alice@work.com"],
                                          groups: groups, contacts: contacts)
            #expect(cc == direct)
        }
    }
}

@Suite("AddressEntry")
struct AddressEntryTests {
    @Suite("formatted")
    struct Formatted {
        @Test("formats as 'Name <email>' when name is present")
        func nameAndEmailWhenPresent() {
            let entry = AddressEntry(name: "Alice Smith", email: "alice@example.com")
            #expect(entry.formatted == "Alice Smith <alice@example.com>")
        }

        @Test("formats as email only when name is empty")
        func emailOnlyWhenNameEmpty() {
            let entry = AddressEntry(name: "", email: "raw@example.com")
            #expect(entry.formatted == "raw@example.com")
        }
    }
}
