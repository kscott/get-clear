// ListHandlerSpec.swift

import Foundation
import GetClearKit
import RemindersLib
import Testing

@Suite("handleList")
struct ListHandlerTests {
    let store = SpyStore()

    @Test("returns grouped rows when no list filter is given")
    func groupedRowsNoFilter() async throws {
        store.lists = [personalList, workList]
        store.items = [makeItem(), makeItem(title: "Team standup", list: workList)]
        let out = try await handleList(args: ["list"], store: store)
        #expect(out.contains("Personal"))
        #expect(out.contains("Work"))
    }

    @Test("returns ungrouped rows when a list filter matches")
    func ungroupedRowsWithFilter() async throws {
        store.lists = [personalList]
        store.items = [makeItem()]
        let out = try await handleList(args: ["list", "Personal"], store: store)
        #expect(out.contains("Pay rent"))
        #expect(!out.contains("\nPersonal"))
    }

    @Test("applies the sort order when 'by' is specified")
    func appliesSortOrder() async throws {
        store.lists = [personalList]
        store.items = [makeItem()]
        let out = try await handleList(args: ["list", "by", "title"], store: store)
        #expect(out.contains("Pay rent"))
    }

    @Test("throws when the named list does not exist")
    func throwsWhenListMissing() async {
        store.lists = [personalList]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleList(args: ["list", "Nonexistent"], store: store)
        }
        #expect(err?.message.contains("Nonexistent") == true)
    }

    @Test("applies the filter and sort order in either order")
    func filterAndByOrderIndependence() async throws {
        store.lists = [personalList]
        store.items = [makeItem()]
        let out = try await handleList(args: ["list", "Personal", "by", "title"], store: store)
        #expect(out.contains("Pay rent"))
    }

    @Test("throws unknown-sort message and does not fall back to due order")
    func throwsUnknownSort() async {
        store.lists = [personalList]
        store.items = [makeItem()]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleList(args: ["list", "by", "sideways"], store: store)
        }
        #expect(err?.message.contains("sideways") == true)
    }

    @Test("throws for a stray token after a quoted filter")
    func throwsForStrayToken() async {
        store.lists = [personalList]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleList(args: ["list", "Personal", "extra"], store: store)
        }
        #expect(err?.message.contains("quote") == true)
    }
}
