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
        let out = try await handleAdd(args: ["add", "Pay rent", "list", "Personal"], store: store)
        #expect(out.contains("Pay rent"))
        #expect(out.contains("Personal"))
    }

    @Test("records the added item with the store")
    func recordsAddedItem() async throws {
        store.lists = [personalList]
        _ = try await handleAdd(args: ["add", "Pay rent", "list", "Personal"], store: store)
        #expect(store.addedItems.count == 1)
        #expect(store.addedItems[0].title == "Pay rent")
    }

    @Test("uses the default list when no list is specified")
    func usesDefaultList() async throws {
        store.lists = [personalList]
        _ = try await handleAdd(args: ["add", "Pay rent"], store: store)
        #expect(store.addedItems[0].list.title == "Personal")
    }

    @Test("sets the due date when a due option is provided")
    func setsDueDate() async throws {
        store.lists = [personalList]
        _ = try await handleAdd(args: ["add", "Pay rent", "list", "Personal", "due", "friday"], store: store)
        #expect(store.addedItems[0].dueDateComponents != nil)
    }

    @Test("sets the due date from a bare leading date")
    func setsDueDateFromBareDate() async throws {
        store.lists = [personalList]
        _ = try await handleAdd(args: ["add", "Pay rent", "friday"], store: store)
        #expect(store.addedItems[0].dueDateComponents != nil)
    }

    @Test("sets the recurrence when a repeat option is provided")
    func setsRecurrence() async throws {
        store.lists = [personalList]
        _ = try await handleAdd(args: ["add", "Pay rent", "list", "Personal", "repeat", "monthly"], store: store)
        #expect(store.addedItems[0].recurrenceSpec != nil)
    }

    @Test("throws with an unrecognized repeat message when the recurrence string is invalid")
    func throwsUnrecognizedRepeat() async {
        store.lists = [personalList]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleAdd(args: ["add", "Pay rent", "list", "Personal", "repeat", "fortnightly"], store: store)
        }
        #expect(err?.message.contains("fortnightly") == true)
    }

    @Test("throws when no title argument is provided")
    func throwsWithoutTitle() async {
        await #expect(throws: ReminderHandlerError.self) {
            try await handleAdd(args: ["add"], store: store)
        }
    }

    @Test("throws unknownKeyword-derived message for a misspelled keyword")
    func throwsForUnknownKeyword() async {
        store.lists = [personalList]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleAdd(args: ["add", "Pay rent", "list", "Personal", "priorty", "high"], store: store)
        }
        #expect(err?.message.contains("priorty") == true)
    }

    @Test("throws missingValue-derived message for a keyword with no value")
    func throwsForMissingValue() async {
        store.lists = [personalList]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleAdd(args: ["add", "Pay rent", "priority"], store: store)
        }
        #expect(err?.message.contains("priority") == true)
    }

    @Test("throws duplicateKeyword-derived message when a keyword is given twice")
    func throwsForDuplicateKeyword() async {
        store.lists = [personalList, workList]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleAdd(args: ["add", "Pay rent", "list", "Personal", "list", "Work"], store: store)
        }
        #expect(err?.message.contains("list") == true)
    }

    @Test("throws for a stray token after a quoted title")
    func throwsForStrayToken() async {
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleAdd(args: ["add", "Pay rent", "list", "Personal", "extra"], store: store)
        }
        #expect(err != nil)
    }

    @Test("throws quote-it hint when 'list' is given bare where the title belongs")
    func throwsQuoteHintForBareListAsTitle() async {
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleAdd(args: ["add", "list"], store: store)
        }
        #expect(err?.message.contains("quote") == true)
    }

    @Test("throws unknown priority and adds nothing")
    func throwsUnknownPriority() async {
        store.lists = [personalList]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleAdd(args: ["add", "Pay rent", "list", "Personal", "priority", "urgent"], store: store)
        }
        #expect(err?.message.contains("urgent") == true)
        #expect(store.addedItems.isEmpty)
    }

    @Test("throws couldn't-parse-date and adds nothing for an unparseable due value")
    func throwsUnparseableDate() async {
        store.lists = [personalList]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleAdd(args: ["add", "Pay rent", "blurgh"], store: store)
        }
        #expect(err?.message.contains("blurgh") == true)
        #expect(store.addedItems.isEmpty)
    }
}
