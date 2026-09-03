import CalendarLib
import Foundation
import Testing

@Suite("handleRemove")
struct RemoveHandlerTests {
    let store = SpyCalendarStore()
    let config = CalendarConfig.empty

    @Test("throws when no title is given")
    func throwsWithoutTitle() async {
        await #expect(throws: (any Error).self) {
            try await handleRemove(args: ["remove"], store: store, calFilter: nil, config: config)
        }
    }

    @Test("throws CalendarHandlerError when event is not found")
    func throwsNotFound() async {
        store.events = []
        let err = await #expect(throws: CalendarHandlerError.self) {
            try await handleRemove(args: ["remove", "Nonexistent"], store: store, calFilter: nil, config: config)
        }
        #expect(err?.description.contains("Not found") == true)
    }

    @Test("calls store.remove with the event identifier")
    func callsStoreRemove() async throws {
        store.events = [makeEvent(identifier: "evt-99", title: "Old Meeting")]
        _ = try await handleRemove(args: ["remove", "Old Meeting"], store: store, calFilter: nil, config: config)
        #expect(store.removedIds.contains("evt-99"))
    }

    @Test("returns a confirmation containing the event title")
    func returnsConfirmation() async throws {
        store.events = [makeEvent(identifier: "evt-1", title: "Old Meeting")]
        let out = try await handleRemove(args: ["remove", "Old Meeting"], store: store, calFilter: nil, config: config)
        #expect(out.contains("Old Meeting"))
    }

    @Test("returns disambiguation message when multiple events match")
    func returnsDisambiguation() async throws {
        store.events = ambiguousEvents()
        let out = try await handleRemove(args: ["remove", "All Hands"], store: store, calFilter: nil, config: config)
        #expect(out.contains("Multiple events match"))
    }

    @Test("throws an unrecognised-range message and removes nothing")
    func throwsForUnrecognisedRange() async {
        store.events = [makeEvent(identifier: "evt-99", title: "Old Meeting")]
        let err = await #expect(throws: CalendarHandlerError.self) {
            try await handleRemove(
                args: ["remove", "Old Meeting", "notarange"], store: store, calFilter: nil, config: config
            )
        }
        #expect(err?.description.contains("notarange") == true)
        #expect(store.removedIds.isEmpty)
    }
}
