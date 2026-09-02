// FindHandlerSpec.swift

import Foundation
import GetClearKit
import RemindersLib
import Testing

@Suite("handleFind")
struct FindHandlerTests {
    let store = SpyStore()

    @Test("returns formatted find rows for matching items")
    func returnsMatchingRows() async throws {
        store.items = [makeItem()]
        let out = try await handleFind(args: ["find", "rent"], store: store)
        #expect(out.contains("Pay rent"))
    }

    @Test("returns a no-match message when nothing matches")
    func returnsNoMatchMessage() async throws {
        store.items = [makeItem(title: "Buy groceries")]
        let out = try await handleFind(args: ["find", "dentist"], store: store)
        #expect(out.contains("dentist"))
        #expect(out.contains("No"))
    }

    @Test("throws when no query argument is provided")
    func throwsWithoutQuery() async {
        await #expect(throws: ReminderHandlerError.self) {
            try await handleFind(args: ["find"], store: store)
        }
    }
}
