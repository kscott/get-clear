import CalendarLib
import Foundation
import Testing

private let range = DateInterval(start: Date(), duration: 86400)

@Suite("resolve")
struct CalendarStoreTests {
    @Suite("exact title match")
    struct ExactTitleMatch {
        let store = SpyCalendarStore()

        @Test("returns the matching event")
        func returnsMatchingEvent() async throws {
            store.events = [makeEvent(identifier: "evt-1", title: "Team Sync")]
            let event = try await store.resolve(title: "Team Sync", in: range, calendarIdentifiers: nil)
            #expect(event.identifier == "evt-1")
        }
    }

    @Suite("case-insensitive contains match")
    struct CaseInsensitiveContainsMatch {
        let store = SpyCalendarStore()

        @Test("returns the event when the title contains the search string")
        func returnsEventOnContains() async throws {
            store.events = [makeEvent(title: "All Hands Meeting")]
            let event = try await store.resolve(title: "all hands", in: range, calendarIdentifiers: nil)
            #expect(event.title == "All Hands Meeting")
        }
    }

    @Suite("not found")
    struct NotFound {
        let store = SpyCalendarStore()

        @Test("throws notFound when no events match")
        func throwsNotFound() async {
            store.events = [makeEvent(title: "Team Sync")]
            await #expect(throws: CalendarStoreError.notFound("Nonexistent")) {
                try await store.resolve(title: "Nonexistent", in: range, calendarIdentifiers: nil)
            }
        }
    }

    @Suite("ambiguous")
    struct Ambiguous {
        let store = SpyCalendarStore()

        @Test("throws ambiguous when multiple events match")
        func throwsAmbiguous() async {
            store.events = ambiguousEvents(title: "All Hands")
            let err = await #expect(throws: CalendarStoreError.self) {
                try await store.resolve(title: "All Hands", in: range, calendarIdentifiers: nil)
            }
            guard case let .ambiguous(matches)? = err else {
                Issue.record("expected ambiguous error")
                return
            }
            #expect(matches.count == 2)
        }
    }
}
