import CalendarLib
import Foundation
import Testing

@Suite("handleAdd")
struct AddHandlerTests {
    let store = SpyCalendarStore()
    let config = CalendarConfig.empty

    @Test("throws when no title is given")
    func throwsWithoutTitle() async {
        await #expect(throws: (any Error).self) {
            try await handleAdd(args: ["add"], store: store, calFilter: nil, config: config)
        }
    }

    @Test("throws for an unrecognised date/time string")
    func throwsForUnrecognisedDateTime() async {
        await #expect(throws: (any Error).self) {
            try await handleAdd(args: ["add", "Meeting", "notadate"], store: store, calFilter: nil, config: config)
        }
    }

    @Test("calls store.add with the correct event title")
    func callsStoreAddWithTitle() async throws {
        _ = try await handleAdd(args: ["add", "Sprint Planning", "tomorrow 10am"], store: store, calFilter: nil, config: config)
        #expect(store.addedItems.first?.title == "Sprint Planning")
    }

    @Test("returns a confirmation containing the event title")
    func returnsConfirmationWithTitle() async throws {
        let out = try await handleAdd(
            args: ["add", "Sprint Planning", "tomorrow 10am"],
            store: store,
            calFilter: nil,
            config: config
        )
        #expect(out.contains("Sprint Planning"))
    }

    @Test("defaults to today when no date is given")
    func defaultsToToday() async throws {
        _ = try await handleAdd(args: ["add", "Quick Check"], store: store, calFilter: nil, config: config)
        #expect(store.addedItems.first?.title == "Quick Check")
    }

    @Test("sets all-day flag for a date-only input")
    func setsAllDayForDateOnly() async throws {
        _ = try await handleAdd(args: ["add", "Holiday", "april 30"], store: store, calFilter: nil, config: config)
        #expect(store.addedItems.first?.isAllDay == true)
    }

    @Test("clears all-day flag for a timed input")
    func clearsAllDayForTimed() async throws {
        _ = try await handleAdd(args: ["add", "Meeting", "tomorrow 2pm"], store: store, calFilter: nil, config: config)
        #expect(store.addedItems.first?.isAllDay == false)
    }

    @Test("throws naming the filter when calFilter matches no calendars, and adds nothing")
    func throwsForUnmatchedCalFilter() async {
        let err = await #expect(throws: CalendarHandlerError.self) {
            try await handleAdd(args: ["add", "Meeting"], store: store, calFilter: "nonexistent", config: config)
        }
        #expect(err?.description.contains("nonexistent") == true)
        #expect(store.addedItems.isEmpty)
    }
}
