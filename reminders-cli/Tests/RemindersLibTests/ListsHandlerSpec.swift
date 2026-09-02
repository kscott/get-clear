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
        let out = try await handleLists(store: store)
        #expect(out == "Personal\nWork")
    }

    @Test("returns empty string when there are no lists")
    func emptyWhenNoLists() async throws {
        store.lists = []
        let out = try await handleLists(store: store)
        #expect(out == "")
    }
}
