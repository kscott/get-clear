// RemoteReminderStoreSpec.swift
//
// Tests for RemindersLib RemoteReminderStore, wired to dispatchReminderRequest and a SpyStore
// through a loopback transport — proving the command side and the helper side agree on every
// store method, with no XPC involved.

import Foundation
import GetClearKit
import RemindersLib
import Testing

private func remote(_ spy: SpyStore) -> RemoteReminderStore {
    RemoteReminderStore(transport: { await dispatchReminderRequest($0.request, to: spy) }, appVersion: "1.4.0")
}

private let range = DateInterval(start: Date(timeIntervalSince1970: 1_790_000_000), duration: 86400)

@Suite("RemoteReminderStore")
struct RemoteReminderStoreTests {
    @Suite("reads")
    struct Reads {
        @Test("fetchLists returns the helper store's lists")
        func fetchLists() async throws {
            let spy = SpyStore()
            spy.lists = [personalList, workList]
            #expect(try await remote(spy).fetchLists() == [personalList, workList])
        }

        @Test("defaultList returns the helper store's default list")
        func defaultList() async throws {
            let spy = SpyStore()
            spy.lists = [workList]
            #expect(try await remote(spy).defaultList() == workList)
        }

        @Test("fetchIncomplete returns the helper store's items")
        func fetchIncomplete() async throws {
            let spy = SpyStore()
            spy.items = [makeItem(identifier: "id-1")]
            #expect(try await remote(spy).fetchIncomplete(in: personalList) == [makeItem(identifier: "id-1")])
        }

        @Test("fetchCompleted passes the range through to the helper store")
        func fetchCompletedRange() async throws {
            let spy = SpyStore()
            _ = try await remote(spy).fetchCompleted(in: range)
            #expect(spy.completedRanges == [range])
        }

        @Test("fetchCompleted returns the helper store's completed items")
        func fetchCompletedItems() async throws {
            let spy = SpyStore()
            spy.completed = [makeItem(identifier: "done-1")]
            #expect(try await remote(spy).fetchCompleted(in: range) == [makeItem(identifier: "done-1")])
        }
    }

    @Suite("writes")
    struct Writes {
        @Test("add sends the item and returns what the helper store saved")
        func add() async throws {
            let spy = SpyStore()
            let item = makeItem(title: "Call dentist", notes: "ask about the crown")
            #expect(try await remote(spy).add(item) == item)
        }

        @Test("update delivers the identifier and changes to the helper store")
        func update() async throws {
            let spy = SpyStore()
            var opts = ParsedOptions()
            opts.priority = "high"
            let changes = try parseReminderChanges(opts, existingItem: makeItem())
            try await remote(spy).update(identifier: "id-1", changes: changes)
            #expect(spy.updatedItems.map { "\($0.id) \($0.changes == changes)" } == ["id-1 true"])
        }

        @Test("complete delivers the identifier to the helper store")
        func complete() async throws {
            let spy = SpyStore()
            try await remote(spy).complete(identifier: "id-1")
            #expect(spy.completedIds == ["id-1"])
        }

        @Test("rename delivers the identifier and new title to the helper store")
        func rename() async throws {
            let spy = SpyStore()
            try await remote(spy).rename(identifier: "id-1", to: "Pay mortgage")
            #expect(spy.renamedItems.map { "\($0.id) \($0.to)" } == ["id-1 Pay mortgage"])
        }

        @Test("delete delivers the identifier to the helper store")
        func delete() async throws {
            let spy = SpyStore()
            try await remote(spy).delete(identifier: "id-1")
            #expect(spy.deletedIds == ["id-1"])
        }
    }

    @Suite("resolve over the helper")
    struct Resolve {
        @Test("a title that matches nothing throws the same typed not-found as a local store")
        func notFoundIsTyped() async {
            await #expect(throws: ReminderStoreError.notFound("Pay rent")) {
                _ = try await remote(SpyStore()).resolve(title: "Pay rent", in: nil)
            }
        }
    }
}
