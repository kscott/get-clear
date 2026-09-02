// ListsHandlerSpec.swift

import Foundation
import GetClearKit
import RemindersLib
import Testing

@Suite("handleLists")
struct ListsHandlerTests {
    let store = SpyStore()

    @Test("returns newline-separated sorted list titles")
    func returnsSortedTitles() async throws {
        store.lists = [workList, personalList]
        let out = try await handleLists(args: ["lists"], store: store)
        #expect(out == "Personal\nWork")
    }

    @Test("returns empty string when there are no lists")
    func emptyWhenNoLists() async throws {
        store.lists = []
        let out = try await handleLists(args: ["lists"], store: store)
        #expect(out == "")
    }

    @Test("throws for a stray token after the command name")
    func throwsForStrayToken() async {
        store.lists = [workList, personalList]
        await #expect(throws: ReminderHandlerError.self) {
            try await handleLists(args: ["lists", "today"], store: store)
        }
    }
}
