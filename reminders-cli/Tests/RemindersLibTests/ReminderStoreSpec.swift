// ReminderStoreSpec.swift
// Tests for ReminderStore.resolve — the default protocol extension for single-item lookup.

import Foundation
import RemindersLib
import Testing

// MARK: - Mock

private final class MockStore: ReminderStore {
    var lists: [ReminderList] = []
    var items: [ReminderItem] = []

    func fetchLists() async throws -> [ReminderList] {
        lists
    }

    func defaultList() async throws -> ReminderList {
        lists.first ?? ReminderList(title: "Reminders")
    }

    func fetchIncomplete(in list: ReminderList?) async throws -> [ReminderItem] {
        items
    }

    func add(_ item: ReminderItem) async throws -> ReminderItem {
        item
    }

    func update(identifier: String, changes: ReminderChanges) async throws {}
    func complete(identifier: String) async throws {}
    func rename(identifier: String, to title: String) async throws {}
    func delete(identifier: String) async throws {}
}

// MARK: - Spec

@Suite("resolve")
struct ReminderStoreTests {
    @Suite("single match")
    struct SingleMatch {
        private let store = MockStore()

        @Test("returns the matched item")
        func returnsMatchedItem() async throws {
            store.items = [makeItem()]
            let result = try await store.resolve(title: "Pay rent", in: nil)
            #expect(result.title == "Pay rent")
        }

        @Test("is case-insensitive")
        func caseInsensitive() async throws {
            store.items = [makeItem(title: "Pay Rent")]
            let result = try await store.resolve(title: "pay rent", in: nil)
            #expect(result.title == "Pay Rent")
        }

        @Test("passes the list filter through to fetchIncomplete")
        func passesListFilter() async throws {
            store.items = [makeItem()]
            let result = try await store.resolve(title: "Pay rent", in: personalList)
            #expect(result.title == "Pay rent")
        }
    }

    @Suite("no match")
    struct NoMatch {
        private let store = MockStore()

        @Test("throws ReminderStoreError.notFound")
        func throwsNotFound() async {
            store.items = []
            await #expect(throws: ReminderStoreError.notFound("Pay rent")) {
                try await store.resolve(title: "Pay rent", in: nil)
            }
        }
    }

    @Suite("multiple matches")
    struct MultipleMatches {
        private let store = MockStore()

        @Test("throws ReminderStoreError.ambiguous with all matches")
        func throwsAmbiguous() async {
            store.items = [makeItem(), makeItem(list: workList)]
            let err = await #expect(throws: ReminderStoreError.self) {
                try await store.resolve(title: "Pay rent", in: nil)
            }
            guard case let .ambiguous(matches)? = err else {
                Issue.record("expected .ambiguous, got \(String(describing: err))")
                return
            }
            #expect(matches.count == 2)
        }
    }
}
