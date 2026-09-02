import CalendarLib
import Foundation
import Testing

@Suite("handleDefault")
struct DefaultHandlerTests {
    let store = SpyCalendarStore()
    let config = CalendarConfig.empty

    @Test("returns nil for a string that is not a valid range")
    func nilForInvalidRange() async throws {
        let out = try await handleDefault(args: ["change"], store: store, calFilter: nil, config: config)
        #expect(out == nil)
    }

    @Test("returns 'No events' message for a valid range with no events")
    func noEventsMessage() async throws {
        store.events = []
        let out = try await handleDefault(args: ["7d"], store: store, calFilter: nil, config: config)
        #expect(out?.contains("No events") == true)
    }

    @Test("returns event output for a valid range with events")
    func eventOutputWithEvents() async throws {
        store.events = [makeEvent(title: "Sprint Review")]
        let out = try await handleDefault(args: ["7d"], store: store, calFilter: nil, config: config)
        #expect(out?.contains("Sprint Review") == true)
    }
}
