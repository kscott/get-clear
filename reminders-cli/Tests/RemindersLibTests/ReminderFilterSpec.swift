// ReminderFilterSpec.swift
// Tests for filtered(_:matching:) and matchesQuery(_:query:) — find command filtering.

import RemindersLib
import Testing

@Suite("filtered")
struct ReminderFilterTests {
    @Suite("title matching")
    struct TitleMatching {
        @Test("returns items whose title contains the query")
        func containsQuery() {
            let items = [makeItem(title: "Pay rent"), makeItem(title: "Buy groceries")]
            #expect(filtered(items, matching: "rent").count == 1)
            #expect(filtered(items, matching: "rent")[0].title == "Pay rent")
        }

        @Test("is case-insensitive")
        func caseInsensitive() {
            let items = [makeItem(title: "Pay Rent")]
            #expect(filtered(items, matching: "RENT").count == 1)
        }

        @Test("matches partial titles")
        func partialTitles() {
            let items = [makeItem(title: "Schedule dentist appointment")]
            #expect(filtered(items, matching: "dentist").count == 1)
        }

        @Test("returns multiple results when several titles match")
        func multipleResults() {
            let items = [makeItem(title: "Pay rent"), makeItem(title: "Review rent agreement"), makeItem(title: "Buy groceries")]
            #expect(filtered(items, matching: "rent").count == 2)
        }
    }

    @Suite("notes matching")
    struct NotesMatching {
        @Test("returns items whose notes contain the query")
        func notesContainQuery() {
            let items = [makeItem(title: "Task", notes: "remember to call Alice")]
            #expect(filtered(items, matching: "call Alice").count == 1)
        }

        @Test("matches notes case-insensitively")
        func notesCaseInsensitive() {
            let items = [makeItem(title: "Task", notes: "URGENT")]
            #expect(filtered(items, matching: "urgent").count == 1)
        }

        @Test("matches items where title does not match but notes do")
        func notesOnlyMatch() {
            let items = [makeItem(title: "Unrelated", notes: "mention of dentist")]
            #expect(filtered(items, matching: "dentist").count == 1)
        }
    }

    @Suite("no match")
    struct NoMatch {
        @Test("returns empty array when no items match")
        func emptyWhenNoMatch() {
            let items = [makeItem(title: "Pay rent"), makeItem(title: "Buy groceries")]
            #expect(filtered(items, matching: "dentist").isEmpty)
        }

        @Test("returns empty array for empty input")
        func emptyForEmptyInput() {
            #expect(filtered([], matching: "anything").isEmpty)
        }
    }
}

@Suite("matchesQuery")
struct MatchesQueryTests {
    @Test("returns true when title contains query")
    func trueWhenTitleContains() {
        #expect(matchesQuery(makeItem(title: "Pay rent"), query: "rent"))
    }

    @Test("returns true when notes contain query")
    func trueWhenNotesContain() {
        #expect(matchesQuery(makeItem(title: "Task", notes: "call Alice"), query: "Alice"))
    }

    @Test("returns false when neither title nor notes contain query")
    func falseWhenNeitherContains() {
        #expect(!matchesQuery(makeItem(title: "Buy groceries"), query: "dentist"))
    }

    @Test("returns false when notes is nil and title does not match")
    func falseWhenNotesNil() {
        #expect(!matchesQuery(makeItem(title: "Buy groceries"), query: "dentist"))
    }
}
