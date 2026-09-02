import CalendarLib
import Foundation
import Testing

@Suite("handleFind")
struct FindHandlerTests {
    let store = SpyCalendarStore()
    let config = CalendarConfig.empty

    @Test("throws when no query is given")
    func throwsWithoutQuery() async {
        await #expect(throws: (any Error).self) {
            try await handleFind(args: ["find"], store: store, calFilter: nil, config: config)
        }
    }

    @Test("returns 'No events matching' when nothing matches")
    func noEventsMatching() async throws {
        store.events = [makeEvent(title: "Team Sync")]
        let out = try await handleFind(args: ["find", "lunch"], store: store, calFilter: nil, config: config)
        #expect(out.contains("No events matching 'lunch'"))
    }

    @Test("returns event title when title matches query")
    func returnsTitleOnMatch() async throws {
        store.events = [makeEvent(title: "Lunch with Alice")]
        let out = try await handleFind(args: ["find", "lunch"], store: store, calFilter: nil, config: config)
        #expect(out.contains("Lunch with Alice"))
    }

    @Test("matches events whose notes contain the query")
    func matchesNotes() async throws {
        store.events = [makeEvent(title: "1:1", notes: "discuss budget")]
        let out = try await handleFind(args: ["find", "budget"], store: store, calFilter: nil, config: config)
        #expect(out.contains("1:1"))
    }
}
