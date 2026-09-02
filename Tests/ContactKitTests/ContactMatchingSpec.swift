// ContactMatchingSpec.swift
//
// Tests for matchContacts — contact query matching and result ordering.

import ContactKit
import ContactTestSupport
import Foundation
import Testing

private let all = [aliceContact, bobContact, charlieContact, noEmailContact, orgOnlyContact]

@Suite("matchContacts")
struct ContactMatchingTests {
    @Suite("name matching")
    struct NameMatching {
        @Test("finds a contact by partial name")
        func findsByPartialName() {
            #expect(matchContacts("alice", in: all).contains { $0.name == "Alice Smith" } == true)
        }

        @Test("returns only the matching contact for a unique query")
        func uniqueQueryReturnsOne() {
            #expect(matchContacts("alice", in: all).count == 1)
        }

        @Test("exact prefix scores first")
        func exactPrefixScoresFirst() {
            #expect(matchContacts("alice", in: all).first?.name == "Alice Smith")
        }

        @Test("finds a contact by last name")
        func findsByLastName() {
            #expect(matchContacts("brown", in: all).contains { $0.name == "Charlie Brown" } == true)
        }

        @Test("exact full name scores first")
        func exactFullNameScoresFirst() {
            #expect(matchContacts("Alice Smith", in: all).first?.name == "Alice Smith")
        }
    }

    @Suite("email matching")
    struct EmailMatching {
        @Test("finds a contact by email domain")
        func findsByEmailDomain() {
            #expect(matchContacts("jones.org", in: all).contains { $0.name == "Bob Jones" } == true)
        }
    }

    @Suite("company matching")
    struct CompanyMatching {
        @Test("finds a contact by exact company name")
        func findsByExactCompany() {
            #expect(matchContacts("acme", in: all).contains { $0.name == "Alice Smith" } == true)
        }

        @Test("finds a contact by partial company name")
        func findsByPartialCompany() {
            #expect(matchContacts("init", in: all).contains { $0.company == "Initech" } == true)
        }
    }

    @Suite("phone matching")
    struct PhoneMatching {
        @Test("finds a contact by digit string")
        func findsByDigitString() {
            #expect(matchContacts("5559999", in: all).contains { $0.name == "Charlie Brown" } == true)
        }

        @Test("normalizes dashes in query")
        func normalizesDashes() {
            #expect(matchContacts("555-9999", in: all).contains { $0.name == "Charlie Brown" } == true)
        }
    }

    @Suite("sort order")
    struct SortOrder {
        @Test("sorts exact name before prefix before substring")
        func sortsExactBeforePrefixBeforeSubstring() {
            let contacts = [
                makeContact(identifier: "jr-id", name: "Smith Jr"),
                makeContact(identifier: "smith-id", name: "Smith"),
                makeContact(identifier: "john-id", name: "John Smith")
            ]
            let r = matchContacts("smith", in: contacts)
            #expect(r[0].name == "Smith")
            #expect(r[1].name == "Smith Jr")
            #expect(r[2].name == "John Smith")
        }
    }

    @Suite("edge cases")
    struct EdgeCases {
        @Test("empty query returns an empty list")
        func emptyQueryEmptyList() {
            #expect(matchContacts("", in: all).isEmpty)
        }

        @Test("unmatched query returns empty")
        func unmatchedQueryEmpty() {
            #expect(matchContacts("xyzzy", in: all).isEmpty)
        }

        @Test("matching is case insensitive")
        func caseInsensitive() {
            #expect(!matchContacts("ALICE", in: all).isEmpty)
        }
    }

    @Suite("identifier preservation")
    struct IdentifierPreservation {
        @Test("returned contact carries the original identifier")
        func carriesOriginalIdentifier() {
            #expect(matchContacts("alice", in: all).first?.identifier == "alice-id")
        }
    }
}
