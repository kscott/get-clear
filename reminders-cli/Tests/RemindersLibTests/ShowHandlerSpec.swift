// ShowHandlerSpec.swift

import Foundation
import GetClearKit
import RemindersLib
import Testing

@Suite("handleShow")
struct ShowHandlerTests {
    let store = SpyStore()

    @Test("returns the formatted show output for the matched item")
    func returnsFormattedOutput() async throws {
        store.items = [makeItem()]
        let out = try await handleShow(args: ["show", "Pay rent"], store: store)
        #expect(out.contains("Pay rent"))
        #expect(out.contains("Personal"))
    }

    @Test("throws with the not-found message when the title is absent")
    func throwsNotFound() async {
        store.items = []
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleShow(args: ["show", "Pay rent"], store: store)
        }
        #expect(err?.message.contains("Pay rent") == true)
    }

    @Test("throws when no title argument is provided")
    func throwsWithoutTitle() async {
        await #expect(throws: ReminderHandlerError.self) {
            try await handleShow(args: ["show"], store: store)
        }
    }
}
