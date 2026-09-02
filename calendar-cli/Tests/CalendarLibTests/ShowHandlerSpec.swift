import CalendarLib
import Foundation
import Testing

@Suite("handleShow")
struct ShowHandlerTests {
    let store = SpyCalendarStore()
    let config = CalendarConfig.empty

    @Test("throws when no title is given")
    func throwsWithoutTitle() async {
        await #expect(throws: (any Error).self) {
            try await handleShow(args: ["show"], store: store, calFilter: nil, config: config)
        }
    }

    @Test("throws CalendarHandlerError when event is not found")
    func throwsNotFound() async {
        store.events = []
        let err = await #expect(throws: CalendarHandlerError.self) {
            try await handleShow(args: ["show", "Nonexistent"], store: store, calFilter: nil, config: config)
        }
        #expect(err?.description.contains("Not found") == true)
    }

    @Test("returns event title in output when found")
    func returnsEventTitle() async throws {
        store.events = [makeEvent(title: "Board Meeting")]
        let out = try await handleShow(args: ["show", "Board Meeting"], store: store, calFilter: nil, config: config)
        #expect(out.contains("Board Meeting"))
    }

    @Test("returns calendar name in output")
    func returnsCalendarName() async throws {
        store.events = [makeEvent(title: "Board Meeting", calendarTitle: "Work")]
        let out = try await handleShow(args: ["show", "Board Meeting"], store: store, calFilter: nil, config: config)
        #expect(out.contains("Work"))
    }

    @Test("returns location when present")
    func returnsLocation() async throws {
        store.events = [makeEvent(title: "Offsite", location: "Conference Room A")]
        let out = try await handleShow(args: ["show", "Offsite"], store: store, calFilter: nil, config: config)
        #expect(out.contains("Conference Room A"))
    }

    @Test("returns attendees with their status when present")
    func returnsAttendees() async throws {
        let attendees = [AttendeeItem(name: "Alice", status: "accepted")]
        store.events = [makeEvent(title: "Review", attendees: attendees)]
        let out = try await handleShow(args: ["show", "Review"], store: store, calFilter: nil, config: config)
        #expect(out.contains("Alice (accepted)"))
    }

    @Test("returns disambiguation message when multiple events match")
    func returnsDisambiguation() async throws {
        store.events = ambiguousEvents(title: "All Hands")
        let out = try await handleShow(args: ["show", "All Hands"], store: store, calFilter: nil, config: config)
        #expect(out.contains("Multiple events match"))
    }

    @Test("omits location line when location is nil")
    func omitsLocationWhenNil() async throws {
        store.events = [makeEvent(title: "No-loc Event", location: nil)]
        let out = try await handleShow(args: ["show", "No-loc Event"], store: store, calFilter: nil, config: config)
        #expect(!out.contains("Location:"))
    }

    @Test("includes 'all day' in the date line for all-day events")
    func includesAllDay() async throws {
        store.events = [makeEvent(title: "Holiday", isAllDay: true)]
        let out = try await handleShow(args: ["show", "Holiday"], store: store, calFilter: nil, config: config)
        #expect(out.contains("all day"))
    }

    @Test("includes notes in output when present")
    func includesNotes() async throws {
        store.events = [makeEvent(title: "Planning", notes: "Review Q2 goals")]
        let out = try await handleShow(args: ["show", "Planning"], store: store, calFilter: nil, config: config)
        #expect(out.contains("Review Q2 goals"))
    }
}
