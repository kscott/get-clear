// DoneHandlerSpec.swift

import Foundation
import GetClearKit
import RemindersLib
import Testing

@Suite("handleDone")
struct DoneHandlerTests {
    let store = SpyStore()

    @Test("returns Done: <title> on success")
    func returnsDoneTitle() async throws {
        store.items = [makeItem(identifier: "id-1")]
        let out = try await handleDone(args: ["done", "Pay rent"], store: store)
        #expect(out == "Done: Pay rent")
    }

    @Test("records the identifier with the store")
    func recordsIdentifier() async throws {
        store.items = [makeItem(identifier: "id-1")]
        _ = try await handleDone(args: ["done", "Pay rent"], store: store)
        #expect(store.completedIds == ["id-1"])
    }

    @Test("filters by the named list")
    func filtersByNamedList() async throws {
        store.lists = [personalList, workList]
        store.items = [makeItem(identifier: "id-1")]
        _ = try await handleDone(args: ["done", "Pay rent", "list", "Personal"], store: store)
        #expect(store.completedIds == ["id-1"])
    }

    @Test("throws the not-found message when the title is absent from the store")
    func throwsNotFound() async {
        store.items = []
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleDone(args: ["done", "Pay rent"], store: store)
        }
        #expect(err?.message.contains("Pay rent") == true)
    }

    @Test("throws when no title argument is provided")
    func throwsWithoutTitle() async {
        await #expect(throws: ReminderHandlerError.self) {
            try await handleDone(args: ["done"], store: store)
        }
    }

    @Test("throws quote-it hint when 'list' is given bare where the title belongs")
    func throwsQuoteHintForBareListAsTitle() async {
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleDone(args: ["done", "list"], store: store)
        }
        #expect(err?.message.contains("quote") == true)
    }

    @Test("throws for a stray token after the title")
    func throwsForStrayToken() async {
        store.items = [makeItem(identifier: "id-1")]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleDone(args: ["done", "Pay rent", "Bills"], store: store)
        }
        #expect(err?.message.contains("quote") == true)
        #expect(store.completedIds.isEmpty)
    }
}
