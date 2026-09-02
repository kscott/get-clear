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

    @Test("filters by the named list")
    func filtersByNamedList() async throws {
        store.lists = [personalList, workList]
        store.items = [makeItem()]
        let out = try await handleShow(args: ["show", "Pay rent", "list", "Personal"], store: store)
        #expect(out.contains("Pay rent"))
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

    @Test("throws quote-it hint when 'list' is given bare where the title belongs")
    func throwsQuoteHintForBareListAsTitle() async {
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleShow(args: ["show", "list"], store: store)
        }
        #expect(err?.message.contains("quote") == true)
    }

    @Test("throws for a stray token after the title")
    func throwsForStrayToken() async {
        store.items = [makeItem()]
        let err = await #expect(throws: ReminderHandlerError.self) {
            try await handleShow(args: ["show", "Pay rent", "Bills"], store: store)
        }
        #expect(err?.message.contains("quote") == true)
    }
}
