// RemoveHandlerSpec.swift

import Foundation
import GetClearKit
import RemindersLib
import Testing

@Suite("handleRemove")
struct RemoveHandlerTests {
    let store = SpyStore()

    @Test("returns the removal confirmation")
    func returnsConfirmation() async throws {
        store.items = [makeItem(identifier: "id-1")]
        let out = try await handleRemove(args: ["remove", "Pay rent"], store: store)
        #expect(out.contains("Pay rent"))
    }

    @Test("records the deleted identifier with the store")
    func recordsDeletedIdentifier() async throws {
        store.items = [makeItem(identifier: "id-1")]
        _ = try await handleRemove(args: ["remove", "Pay rent"], store: store)
        #expect(store.deletedIds == ["id-1"])
    }

    @Test("throws with the not-found message when the title is absent from the store")
    func throwsNotFound() async {
        store.items = []
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleRemove(args: ["remove", "Pay rent"], store: store)
        }
        #expect(err?.message.contains("Pay rent") == true)
    }

    @Test("throws with the disambiguation message when the title is ambiguous")
    func throwsDisambiguation() async {
        store.items = ambiguousItems()
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleRemove(args: ["remove", "Pay rent"], store: store)
        }
        #expect(err?.message.contains("remove") == true)
    }

    @Test("filters by the named list")
    func filtersByNamedList() async throws {
        store.lists = [personalList, workList]
        store.items = [makeItem(identifier: "id-1")]
        _ = try await handleRemove(args: ["remove", "Pay rent", "Personal"], store: store)
        #expect(store.deletedIds == ["id-1"])
    }

    @Test("throws when the named list does not exist")
    func throwsWhenListMissing() async {
        store.lists = [personalList]
        store.items = [makeItem(identifier: "id-1")]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleRemove(args: ["remove", "Pay rent", "Nonexistent"], store: store)
        }
        #expect(err?.message.contains("Nonexistent") == true)
    }
}
