import CalendarLib
import Foundation
import Testing

@Suite("handleNext")
struct NextHandlerTests {
    let store = SpyCalendarStore()
    let config = CalendarConfig.empty

    @Test("returns 'No upcoming events' when store is empty")
    func noUpcomingEvents() async throws {
        store.events = []
        let out = try await handleNext(args: ["next"], store: store, calFilter: nil, config: config)
        #expect(out.contains("No upcoming events"))
    }

    @Test("returns event title for upcoming events")
    func returnsEventTitle() async throws {
        store.events = [makeEvent(title: "Quarterly Review", dayOffset: 1)]
        let out = try await handleNext(args: ["next"], store: store, calFilter: nil, config: config)
        #expect(out.contains("Quarterly Review"))
    }

    @Test("defaults to 5 events when no count argument is given")
    func defaultsToFive() async throws {
        store.events = (1 ... 10).map { makeEvent(identifier: "e\($0)", title: "Event \($0)", dayOffset: $0) }
        let out = try await handleNext(args: ["next"], store: store, calFilter: nil, config: config)
        let lines = out.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 5)
    }

    @Test("respects a custom count argument")
    func respectsCustomCount() async throws {
        store.events = (1 ... 10).map { makeEvent(identifier: "e\($0)", title: "Event \($0)", dayOffset: $0) }
        let out = try await handleNext(args: ["next", "3"], store: store, calFilter: nil, config: config)
        let lines = out.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 3)
    }

    @Test("appends location to the event line when present")
    func appendsLocation() async throws {
        store.events = [makeEvent(title: "Offsite", dayOffset: 1, location: "Building 2")]
        let out = try await handleNext(args: ["next"], store: store, calFilter: nil, config: config)
        #expect(out.contains("Building 2"))
    }

    @Test("throws an invalid-count message for a non-numeric count, instead of silently defaulting")
    func throwsForNonNumericCount() async {
        let err = await #expect(throws: CalendarHandlerError.self) {
            try await handleNext(args: ["next", "many"], store: store, calFilter: nil, config: config)
        }
        #expect(err?.description.contains("many") == true)
    }

    @Test("throws for a stray token after the count")
    func throwsForStrayToken() async {
        await #expect(throws: CalendarHandlerError.self) {
            try await handleNext(args: ["next", "3", "extra"], store: store, calFilter: nil, config: config)
        }
    }
}
