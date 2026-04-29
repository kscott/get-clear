// ReminderHandlersSpec.swift
// Tests for store-dependent handlers — each handler returns a String, throws ReminderHandlerError.

import Quick
import Nimble
import Foundation
import GetClearKit
import RemindersLib

// MARK: - Mock

final class SpyStore: ReminderStore {
    var lists: [ReminderList]  = []
    var items: [ReminderItem]  = []

    var addedItems:   [ReminderItem]                         = []
    var completedIds: [String]                               = []
    var deletedIds:   [String]                               = []
    var renamedItems: [(id: String, to: String)]             = []
    var updatedItems: [(id: String, changes: ReminderChanges)] = []

    func fetchLists() async throws -> [ReminderList]                              { lists }
    func defaultList() async throws -> ReminderList                               { lists.first ?? ReminderList(title: "Reminders") }
    func fetchIncomplete(in list: ReminderList?) async throws -> [ReminderItem]   { items }
    func add(_ item: ReminderItem) async throws -> ReminderItem                   { addedItems.append(item); return item }
    func update(identifier: String, changes: ReminderChanges) async throws        { updatedItems.append((identifier, changes)) }
    func complete(identifier: String) async throws                                { completedIds.append(identifier) }
    func rename(identifier: String, to title: String) async throws                { renamedItems.append((identifier, title)) }
    func delete(identifier: String) async throws                                  { deletedIds.append(identifier) }
}

// MARK: - Spec

final class ReminderHandlersSpec: AsyncSpec {
    override class func spec() {

        var store: SpyStore!

        beforeEach { store = SpyStore() }

        // MARK: handleLists

        describe("handleLists") {
            it("returns newline-separated sorted list titles") {
                store.lists = [workList, personalList]
                let out = try await handleLists(store: store)
                expect(out) == "Personal\nWork"
            }
            it("returns empty string when there are no lists") {
                store.lists = []
                let out = try await handleLists(store: store)
                expect(out) == ""
            }
        }

        // MARK: handleList

        describe("handleList") {
            it("returns grouped rows when no list filter is given") {
                store.lists = [personalList, workList]
                store.items = [makeItem(), makeItem(title: "Team standup", list: workList)]
                let out = try await handleList(args: ["list"], store: store)
                expect(out).to(contain("Personal"))
                expect(out).to(contain("Work"))
            }
            it("returns ungrouped rows when a list filter matches") {
                store.lists = [personalList]
                store.items = [makeItem()]
                let out = try await handleList(args: ["list", "Personal"], store: store)
                expect(out).to(contain("Pay rent"))
                expect(out).notTo(contain("\nPersonal"))
            }
            it("applies the sort order when 'by' is specified") {
                store.lists = [personalList]
                store.items = [makeItem()]
                let out = try await handleList(args: ["list", "by", "title"], store: store)
                expect(out).to(contain("Pay rent"))
            }
            it("throws when the named list does not exist") {
                store.lists = [personalList]
                await expect {
                    try await handleList(args: ["list", "Nonexistent"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("Nonexistent"))
                })
            }
        }

        // MARK: handleFind

        describe("handleFind") {
            it("returns formatted find rows for matching items") {
                store.items = [makeItem()]
                let out = try await handleFind(args: ["find", "rent"], store: store)
                expect(out).to(contain("Pay rent"))
            }
            it("returns a no-match message when nothing matches") {
                store.items = [makeItem(title: "Buy groceries")]
                let out = try await handleFind(args: ["find", "dentist"], store: store)
                expect(out).to(contain("dentist"))
                expect(out).to(contain("No"))
            }
            it("throws when no query argument is provided") {
                await expect {
                    try await handleFind(args: ["find"], store: store)
                }.to(throwError(errorType: ReminderHandlerError.self))
            }
        }

        // MARK: handleShow

        describe("handleShow") {
            it("returns the formatted show output for the matched item") {
                store.items = [makeItem()]
                let out = try await handleShow(args: ["show", "Pay rent"], store: store)
                expect(out).to(contain("Pay rent"))
                expect(out).to(contain("Personal"))
            }
            it("throws with the not-found message when the title is absent") {
                store.items = []
                await expect {
                    try await handleShow(args: ["show", "Pay rent"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("Pay rent"))
                })
            }
            it("throws when no title argument is provided") {
                await expect {
                    try await handleShow(args: ["show"], store: store)
                }.to(throwError(errorType: ReminderHandlerError.self))
            }
        }

        // MARK: handleDone

        describe("handleDone") {
            it("returns Done: <title> on success") {
                store.items = [makeItem(identifier: "id-1")]
                let out = try await handleDone(args: ["done", "Pay rent"], store: store)
                expect(out) == "Done: Pay rent"
            }
            it("records the identifier with the store") {
                store.items = [makeItem(identifier: "id-1")]
                _ = try await handleDone(args: ["done", "Pay rent"], store: store)
                expect(store.completedIds) == ["id-1"]
            }
            it("throws the not-found message when the title is absent from the store") {
                store.items = []
                await expect {
                    try await handleDone(args: ["done", "Pay rent"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("Pay rent"))
                })
            }
            it("throws when no title argument is provided") {
                await expect {
                    try await handleDone(args: ["done"], store: store)
                }.to(throwError(errorType: ReminderHandlerError.self))
            }
        }

        // MARK: handleRename

        describe("handleRename") {
            it("returns the rename confirmation") {
                store.items = [makeItem(identifier: "id-1")]
                let out = try await handleRename(args: ["rename", "Pay rent", "Pay mortgage"], store: store)
                expect(out).to(contain("Pay rent"))
                expect(out).to(contain("Pay mortgage"))
            }
            it("records the new title with the store") {
                store.items = [makeItem(identifier: "id-1")]
                _ = try await handleRename(args: ["rename", "Pay rent", "Pay mortgage"], store: store)
                expect(store.renamedItems.count) == 1
                expect(store.renamedItems[0].id) == "id-1"
                expect(store.renamedItems[0].to) == "Pay mortgage"
            }
            it("throws when fewer than 2 title arguments are provided") {
                await expect {
                    try await handleRename(args: ["rename", "Pay rent"], store: store)
                }.to(throwError(errorType: ReminderHandlerError.self))
            }
            it("throws with the not-found message when the title is absent from the store") {
                store.items = []
                await expect {
                    try await handleRename(args: ["rename", "Pay rent", "Pay mortgage"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("Pay rent"))
                })
            }
            it("throws with the disambiguation message when the title is ambiguous") {
                store.items = ambiguousItems()
                await expect {
                    try await handleRename(args: ["rename", "Pay rent", "Pay mortgage"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("rename"))
                })
            }
        }

        // MARK: handleRemove

        describe("handleRemove") {
            it("returns the removal confirmation") {
                store.items = [makeItem(identifier: "id-1")]
                let out = try await handleRemove(args: ["remove", "Pay rent"], store: store)
                expect(out).to(contain("Pay rent"))
            }
            it("records the deleted identifier with the store") {
                store.items = [makeItem(identifier: "id-1")]
                _ = try await handleRemove(args: ["remove", "Pay rent"], store: store)
                expect(store.deletedIds) == ["id-1"]
            }
            it("throws with the not-found message when the title is absent from the store") {
                store.items = []
                await expect {
                    try await handleRemove(args: ["remove", "Pay rent"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("Pay rent"))
                })
            }
            it("throws with the disambiguation message when the title is ambiguous") {
                store.items = ambiguousItems()
                await expect {
                    try await handleRemove(args: ["remove", "Pay rent"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("remove"))
                })
            }
            it("filters by the named list") {
                store.lists = [personalList, workList]
                store.items = [makeItem(identifier: "id-1")]
                _ = try await handleRemove(args: ["remove", "Pay rent", "Personal"], store: store)
                expect(store.deletedIds) == ["id-1"]
            }
            it("throws when the named list does not exist") {
                store.lists = [personalList]
                store.items = [makeItem(identifier: "id-1")]
                await expect {
                    try await handleRemove(args: ["remove", "Pay rent", "Nonexistent"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("Nonexistent"))
                })
            }
        }

        // MARK: handleAdd

        describe("handleAdd") {
            it("returns the add confirmation including the list name") {
                store.lists = [personalList]
                let out = try await handleAdd(args: ["add", "Pay rent", "Personal"], store: store)
                expect(out).to(contain("Pay rent"))
                expect(out).to(contain("Personal"))
            }
            it("records the added item with the store") {
                store.lists = [personalList]
                _ = try await handleAdd(args: ["add", "Pay rent", "Personal"], store: store)
                expect(store.addedItems.count) == 1
                expect(store.addedItems[0].title) == "Pay rent"
            }
            it("uses the default list when no list is specified") {
                store.lists = [personalList]
                _ = try await handleAdd(args: ["add", "Pay rent"], store: store)
                expect(store.addedItems[0].list.title) == "Personal"
            }
            it("sets the due date when a date option is provided") {
                store.lists = [personalList]
                _ = try await handleAdd(args: ["add", "Pay rent", "Personal", "due", "friday"], store: store)
                expect(store.addedItems[0].dueDateComponents).notTo(beNil())
            }
            it("sets the recurrence when a repeat option is provided") {
                store.lists = [personalList]
                _ = try await handleAdd(args: ["add", "Pay rent", "Personal", "repeat", "monthly"], store: store)
                expect(store.addedItems[0].recurrenceSpec).notTo(beNil())
            }
            it("throws with an unrecognized repeat message when the recurrence string is invalid") {
                store.lists = [personalList]
                await expect {
                    try await handleAdd(args: ["add", "Pay rent", "Personal", "repeat", "fortnightly"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("fortnightly"))
                })
            }
            it("throws when no title argument is provided") {
                await expect {
                    try await handleAdd(args: ["add"], store: store)
                }.to(throwError(errorType: ReminderHandlerError.self))
            }
        }

        // MARK: handleChange

        describe("handleChange") {
            it("returns the update confirmation with change descriptions") {
                store.items = [makeItem(identifier: "id-1")]
                let out = try await handleChange(args: ["change", "Pay rent", "priority", "high"], store: store)
                expect(out).to(contain("Pay rent"))
                expect(out).to(contain("high"))
            }
            it("records the update with the store") {
                store.items = [makeItem(identifier: "id-1")]
                _ = try await handleChange(args: ["change", "Pay rent", "priority", "high"], store: store)
                expect(store.updatedItems.count) == 1
                expect(store.updatedItems[0].id) == "id-1"
            }
            it("throws when no title argument is provided") {
                await expect {
                    try await handleChange(args: ["change"], store: store)
                }.to(throwError(errorType: ReminderHandlerError.self))
            }
            it("throws when there is nothing to change") {
                store.items = [makeItem(identifier: "id-1")]
                await expect {
                    try await handleChange(args: ["change", "Pay rent"], store: store)
                }.to(throwError(errorType: ReminderHandlerError.self))
            }
            it("throws with the not-found message when the title is absent from the store") {
                store.items = []
                await expect {
                    try await handleChange(args: ["change", "Pay rent", "priority", "high"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("Pay rent"))
                })
            }
            it("throws with the disambiguation message when the title is ambiguous") {
                store.items = ambiguousItems()
                await expect {
                    try await handleChange(args: ["change", "Pay rent", "priority", "high"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("change"))
                })
            }
            it("throws with unrecognized recurrence message") {
                store.items = [makeItem(identifier: "id-1")]
                await expect {
                    try await handleChange(args: ["change", "Pay rent", "repeat", "fortnightly"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("fortnightly"))
                })
            }
            it("carries existing item values as from in ValueChange") {
                store.items = [makeItem(identifier: "id-1", priority: 5, notes: "old note")]
                _ = try await handleChange(args: ["change", "Pay rent", "priority", "high"], store: store)
                let changes = store.updatedItems[0].changes
                expect(changes.priority) == .replaced(from: 5, to: 1)
                expect(changes.note) == .unchanged
            }
            it("produces added when existing optional field is nil") {
                store.items = [makeItem(identifier: "id-1")]
                _ = try await handleChange(args: ["change", "Pay rent", "note", "buy milk"], store: store)
                let changes = store.updatedItems[0].changes
                expect(changes.note) == .added("buy milk")
            }
            it("produces replaced when existing optional field is present") {
                store.items = [makeItem(identifier: "id-1", notes: "old note")]
                _ = try await handleChange(args: ["change", "Pay rent", "note", "new note"], store: store)
                let changes = store.updatedItems[0].changes
                expect(changes.note) == .replaced(from: "old note", to: "new note")
            }
        }
    }
}
