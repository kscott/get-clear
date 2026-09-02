// AddHandlerSpec.swift

import Foundation
import GetClearKit
import RemindersLib
import Testing

@Suite("handleAdd")
struct AddHandlerTests {
    let store = SpyStore()

    @Test("returns the add confirmation including the list name")
    func returnsConfirmationWithListName() async throws {
        store.lists = [personalList]
        let out = try await handleAdd(args: ["add", "Pay rent", "Personal"], store: store)
        #expect(out.contains("Pay rent"))
        #expect(out.contains("Personal"))
    }

    @Test("records the added item with the store")
    func recordsAddedItem() async throws {
        store.lists = [personalList]
        _ = try await handleAdd(args: ["add", "Pay rent", "Personal"], store: store)
        #expect(store.addedItems.count == 1)
        #expect(store.addedItems[0].title == "Pay rent")
    }

    @Test("uses the default list when no list is specified")
    func usesDefaultList() async throws {
        store.lists = [personalList]
        _ = try await handleAdd(args: ["add", "Pay rent"], store: store)
        #expect(store.addedItems[0].list.title == "Personal")
    }

    @Test("sets the due date when a date option is provided")
    func setsDueDate() async throws {
        store.lists = [personalList]
        _ = try await handleAdd(args: ["add", "Pay rent", "Personal", "due", "friday"], store: store)
        #expect(store.addedItems[0].dueDateComponents != nil)
    }

    @Test("sets the recurrence when a repeat option is provided")
    func setsRecurrence() async throws {
        store.lists = [personalList]
        _ = try await handleAdd(args: ["add", "Pay rent", "Personal", "repeat", "monthly"], store: store)
        #expect(store.addedItems[0].recurrenceSpec != nil)
    }

    @Test("throws with an unrecognized repeat message when the recurrence string is invalid")
    func throwsUnrecognizedRepeat() async {
        store.lists = [personalList]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleAdd(args: ["add", "Pay rent", "Personal", "repeat", "fortnightly"], store: store)
        }
        #expect(err?.message.contains("fortnightly") == true)
    }

    @Test("throws when no title argument is provided")
    func throwsWithoutTitle() async {
        await #expect(throws: ReminderHandlerError.self) {
            try await handleAdd(args: ["add"], store: store)
        }
    }
}
