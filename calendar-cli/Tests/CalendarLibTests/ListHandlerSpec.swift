import CalendarLib
import Foundation
import Testing

@Suite("handleList")
struct ListHandlerTests {
    let store = SpyCalendarStore()
    let config = CalendarConfig.empty

    @Test("throws when no range argument is given")
    func throwsWithoutRange() async {
        await #expect(throws: (any Error).self) {
            try await handleList(args: ["list"], store: store, calFilter: nil, config: config)
        }
    }

    @Test("throws for an unrecognised range string")
    func throwsForUnrecognisedRange() async {
        await #expect(throws: (any Error).self) {
            try await handleList(args: ["list", "notarange"], store: store, calFilter: nil, config: config)
        }
    }

    @Test("returns 'No events' message when store is empty")
    func noEventsMessage() async throws {
        store.events = []
        let out = try await handleList(args: ["list", "7d"], store: store, calFilter: nil, config: config)
        #expect(out.contains("No events"))
    }

    @Test("returns event title when events exist")
    func returnsEventTitle() async throws {
        store.events = [makeEvent(title: "Sprint Review")]
        let out = try await handleList(args: ["list", "7d"], store: store, calFilter: nil, config: config)
        #expect(out.contains("Sprint Review"))
    }

    @Test("returns grouped output for a multi-day range")
    func groupedOutputMultiDay() async throws {
        store.events = [makeEvent(title: "Day 1"), makeEvent(title: "Day 2", dayOffset: 3)]
        let out = try await handleList(args: ["list", "7d"], store: store, calFilter: nil, config: config)
        #expect(out.contains("Day 1"))
        #expect(out.contains("Day 2"))
    }
}
