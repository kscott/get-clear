// RenameHandlerSpec.swift

import Foundation
import GetClearKit
import RemindersLib
import Testing

@Suite("handleRename")
struct RenameHandlerTests {
    let store = SpyStore()

    @Test("returns the rename confirmation")
    func returnsConfirmation() async throws {
        store.items = [makeItem(identifier: "id-1")]
        let out = try await handleRename(args: ["rename", "Pay rent", "Pay mortgage"], store: store)
        #expect(out.contains("Pay rent"))
        #expect(out.contains("Pay mortgage"))
    }

    @Test("records the new title with the store")
    func recordsNewTitle() async throws {
        store.items = [makeItem(identifier: "id-1")]
        _ = try await handleRename(args: ["rename", "Pay rent", "Pay mortgage"], store: store)
        #expect(store.renamedItems.count == 1)
        #expect(store.renamedItems[0].id == "id-1")
        #expect(store.renamedItems[0].to == "Pay mortgage")
    }

    @Test("filters by the named list")
    func filtersByNamedList() async throws {
        store.lists = [personalList, workList]
        store.items = [makeItem(identifier: "id-1")]
        _ = try await handleRename(args: ["rename", "Pay rent", "Pay mortgage", "list", "Personal"], store: store)
        #expect(store.renamedItems.count == 1)
    }

    @Test("throws when fewer than 2 title arguments are provided")
    func throwsWithFewerThanTwoTitles() async {
        await #expect(throws: ReminderHandlerError.self) {
            try await handleRename(args: ["rename", "Pay rent"], store: store)
        }
    }

    @Test("throws with the not-found message when the title is absent from the store")
    func throwsNotFound() async {
        store.items = []
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleRename(args: ["rename", "Pay rent", "Pay mortgage"], store: store)
        }
        #expect(err?.message.contains("Pay rent") == true)
    }

    @Test("throws with the disambiguation message when the title is ambiguous")
    func throwsDisambiguation() async {
        store.items = ambiguousItems()
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleRename(args: ["rename", "Pay rent", "Pay mortgage"], store: store)
        }
        #expect(err?.message.contains("rename") == true)
    }

    @Test("throws quote-it hint when 'list' is given bare where the new title belongs")
    func throwsQuoteHintForBareListAsNewTitle() async {
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleRename(args: ["rename", "Buy milk", "list"], store: store)
        }
        #expect(err?.message.contains("quote") == true)
    }

    @Test("throws for a stray token after both titles")
    func throwsForStrayToken() async {
        store.items = [makeItem(identifier: "id-1")]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleRename(args: ["rename", "Pay rent", "Pay mortgage", "Bills"], store: store)
        }
        #expect(err?.message.contains("quote") == true)
        #expect(store.renamedItems.isEmpty)
    }
}
