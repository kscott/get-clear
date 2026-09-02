// ChangeHandlerSpec.swift

import Foundation
import GetClearKit
import RemindersLib
import Testing

@Suite("handleChange")
struct ChangeHandlerTests {
    let store = SpyStore()

    @Test("returns the update confirmation with change descriptions")
    func returnsConfirmation() async throws {
        store.items = [makeItem(identifier: "id-1")]
        let out = try await handleChange(args: ["change", "Pay rent", "priority", "high"], store: store)
        #expect(out.contains("Pay rent"))
        #expect(out.contains("high"))
    }

    @Test("records the update with the store")
    func recordsUpdate() async throws {
        store.items = [makeItem(identifier: "id-1")]
        _ = try await handleChange(args: ["change", "Pay rent", "priority", "high"], store: store)
        #expect(store.updatedItems.count == 1)
        #expect(store.updatedItems[0].id == "id-1")
    }

    @Test("filters by the named list")
    func filtersByNamedList() async throws {
        store.lists = [personalList, workList]
        store.items = [makeItem(identifier: "id-1")]
        _ = try await handleChange(
            args: ["change", "Pay rent", "list", "Personal", "priority", "high"], store: store
        )
        #expect(store.updatedItems.count == 1)
    }

    @Test("throws when no title argument is provided")
    func throwsWithoutTitle() async {
        await #expect(throws: ReminderHandlerError.self) {
            try await handleChange(args: ["change"], store: store)
        }
    }

    @Test("throws when there is nothing to change")
    func throwsWhenNothingToChange() async {
        store.items = [makeItem(identifier: "id-1")]
        await #expect(throws: ReminderHandlerError.self) {
            try await handleChange(args: ["change", "Pay rent"], store: store)
        }
    }

    @Test("throws with the not-found message when the title is absent from the store")
    func throwsNotFound() async {
        store.items = []
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleChange(args: ["change", "Pay rent", "priority", "high"], store: store)
        }
        #expect(err?.message.contains("Pay rent") == true)
    }

    @Test("throws with the disambiguation message when the title is ambiguous")
    func throwsDisambiguation() async {
        store.items = ambiguousItems()
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleChange(args: ["change", "Pay rent", "priority", "high"], store: store)
        }
        #expect(err?.message.contains("change") == true)
    }

    @Test("throws with unrecognized recurrence message")
    func throwsUnrecognizedRecurrence() async {
        store.items = [makeItem(identifier: "id-1")]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleChange(args: ["change", "Pay rent", "repeat", "fortnightly"], store: store)
        }
        #expect(err?.message.contains("fortnightly") == true)
    }

    @Test("carries existing item values as from in ValueChange")
    func carriesExistingValues() async throws {
        store.items = [makeItem(identifier: "id-1", priority: 5, notes: "old note")]
        _ = try await handleChange(args: ["change", "Pay rent", "priority", "high"], store: store)
        let changes = store.updatedItems[0].changes
        #expect(changes.priority == .replaced(from: 5, to: 1))
        #expect(changes.note == .unchanged)
    }

    @Test("produces added when existing optional field is nil")
    func producesAddedWhenNil() async throws {
        store.items = [makeItem(identifier: "id-1")]
        _ = try await handleChange(args: ["change", "Pay rent", "note", "buy milk"], store: store)
        let changes = store.updatedItems[0].changes
        #expect(changes.note == .added("buy milk"))
    }

    @Test("produces replaced when existing optional field is present")
    func producesReplacedWhenPresent() async throws {
        store.items = [makeItem(identifier: "id-1", notes: "old note")]
        _ = try await handleChange(args: ["change", "Pay rent", "note", "new note"], store: store)
        let changes = store.updatedItems[0].changes
        #expect(changes.note == .replaced(from: "old note", to: "new note"))
    }

    @Test("throws unknownKeyword-derived message for a misspelled keyword")
    func throwsForUnknownKeyword() async {
        store.items = [makeItem(identifier: "id-1")]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleChange(args: ["change", "Pay rent", "priorty", "high"], store: store)
        }
        #expect(err?.message.contains("priorty") == true)
    }

    @Test("throws missingValue-derived message for a keyword with no value")
    func throwsForMissingValue() async {
        store.items = [makeItem(identifier: "id-1")]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleChange(args: ["change", "Pay rent", "priority"], store: store)
        }
        #expect(err?.message.contains("priority") == true)
    }

    @Test("throws duplicateKeyword-derived message when a keyword is given twice")
    func throwsForDuplicateKeyword() async {
        store.items = [makeItem(identifier: "id-1")]
        store.lists = [personalList, workList]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleChange(
                args: ["change", "Pay rent", "list", "Personal", "list", "Work"], store: store
            )
        }
        #expect(err?.message.contains("list") == true)
    }

    @Test("throws quote-it hint when 'list' is given bare where the title belongs")
    func throwsQuoteHintForBareListAsTitle() async {
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleChange(args: ["change", "list"], store: store)
        }
        #expect(err?.message.contains("quote") == true)
    }

    @Test("throws dateGivenTwice-derived message and makes no change for date given two ways")
    func throwsDateGivenTwiceMakesNoChange() async {
        store.items = [makeItem(identifier: "id-1")]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleChange(args: ["change", "Pay rent", "march", "1", "due", "none"], store: store)
        }
        #expect(err?.message.contains("two ways") == true)
        #expect(store.updatedItems.isEmpty)
    }

    @Test("throws couldn't-parse-date message and makes no change for an unparseable bare date")
    func throwsUnparseableDateMakesNoChange() async {
        store.items = [makeItem(identifier: "id-1")]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleChange(args: ["change", "Pay rent", "blurgh"], store: store)
        }
        #expect(err?.message.contains("blurgh") == true)
        #expect(store.updatedItems.isEmpty)
    }

    @Test("throws unknown priority message and makes no change")
    func throwsUnknownPriorityMakesNoChange() async {
        store.items = [makeItem(identifier: "id-1")]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleChange(args: ["change", "Pay rent", "priority", "urgent"], store: store)
        }
        #expect(err?.message.contains("urgent") == true)
        #expect(store.updatedItems.isEmpty)
    }
}
