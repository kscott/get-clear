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
}
