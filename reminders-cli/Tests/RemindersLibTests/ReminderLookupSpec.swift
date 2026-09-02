// ReminderLookupSpec.swift
// Tests for lookup(title:in:) — exact case-insensitive match with disambiguation.

import RemindersLib
import Testing

@Suite("lookup")
struct ReminderLookupTests {
    @Suite("single match")
    struct SingleMatch {
        @Test("returns found with the correct index")
        func foundCorrectIndex() {
            let items = [makeItem(title: "Pay rent"), makeItem(title: "Buy groceries")]
            #expect(lookup(title: "Pay rent", in: items) == .found(0))
        }

        @Test("returns found at a non-zero index")
        func foundNonZeroIndex() {
            let items = [makeItem(title: "Buy groceries"), makeItem(title: "Pay rent")]
            #expect(lookup(title: "Pay rent", in: items) == .found(1))
        }

        @Test("is case-insensitive")
        func caseInsensitive() {
            let items = [makeItem(title: "Pay Rent")]
            #expect(lookup(title: "pay rent", in: items) == .found(0))
        }

        @Test("requires an exact match — does not match substrings")
        func requiresExactMatch() {
            let items = [makeItem(title: "Pay rent this month")]
            #expect(lookup(title: "Pay rent", in: items) == .notFound)
        }
    }

    @Suite("no match")
    struct NoMatch {
        @Test("returns notFound when no title matches")
        func notFoundWhenNoMatch() {
            let items = [makeItem(title: "Buy groceries")]
            #expect(lookup(title: "Pay rent", in: items) == .notFound)
        }

        @Test("returns notFound for empty array")
        func notFoundForEmpty() {
            #expect(lookup(title: "Pay rent", in: []) == .notFound)
        }
    }

    @Suite("multiple matches")
    struct MultipleMatches {
        @Test("returns ambiguous with indices of all matching items")
        func ambiguousWithIndices() {
            let items = [
                makeItem(title: "Pay rent", list: personalList),
                makeItem(title: "Buy groceries"),
                makeItem(title: "Pay rent", list: workList)
            ]
            #expect(lookup(title: "Pay rent", in: items) == .ambiguous([0, 2]))
        }

        @Test("is case-insensitive for ambiguous matches")
        func caseInsensitiveAmbiguous() {
            let items = [
                makeItem(title: "Pay Rent", list: personalList),
                makeItem(title: "PAY RENT", list: workList)
            ]
            #expect(lookup(title: "pay rent", in: items) == .ambiguous([0, 1]))
        }
    }
}
