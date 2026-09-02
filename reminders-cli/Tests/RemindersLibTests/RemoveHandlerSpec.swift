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
        _ = try await handleRemove(args: ["remove", "Pay rent", "list", "Personal"], store: store)
        #expect(store.deletedIds == ["id-1"])
    }

    @Test("throws when the named list does not exist")
    func throwsWhenListMissing() async {
        store.lists = [personalList]
        store.items = [makeItem(identifier: "id-1")]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleRemove(args: ["remove", "Pay rent", "list", "Nonexistent"], store: store)
        }
        #expect(err?.message.contains("Nonexistent") == true)
    }

    @Test("throws for a stray unquoted token where the list keyword belongs")
    func throwsForStrayToken() async {
        store.items = [makeItem(identifier: "id-1")]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleRemove(args: ["remove", "Pay rent", "Household", "Bills"], store: store)
        }
        #expect(err?.message.contains("quote") == true)
        #expect(store.deletedIds.isEmpty)
    }

    @Test("throws when no title argument is provided")
    func throwsWithoutTitle() async {
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleRemove(args: ["remove"], store: store)
        }
        #expect(err != nil)
    }

    @Test("throws quote-it hint when 'list' is given bare where the title belongs")
    func throwsQuoteHintForBareListAsTitle() async {
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleRemove(args: ["remove", "list"], store: store)
        }
        #expect(err?.message.contains("quote") == true)
    }

    @Test("throws with the unknown-list message and removes nothing")
    func throwsUnknownListRemovesNothing() async {
        store.lists = [personalList]
        store.items = [makeItem(identifier: "id-1")]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleRemove(args: ["remove", "Pay rent", "list", "No Such List"], store: store)
        }
        #expect(err?.message.contains("No Such List") == true)
        #expect(store.deletedIds.isEmpty)
    }
}
