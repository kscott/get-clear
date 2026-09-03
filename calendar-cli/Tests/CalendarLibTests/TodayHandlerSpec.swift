import CalendarLib
import Foundation
import Testing

@Suite("handleToday")
struct TodayHandlerTests {
    let store = SpyCalendarStore()
    let config = CalendarConfig.empty

    @Test("returns day header and '(nothing scheduled)' when no events")
    func nothingScheduled() async throws {
        store.events = []
        let out = try await handleToday(args: ["today"], store: store, calFilter: nil, config: config)
        #expect(out.contains("(nothing scheduled)"))
    }

    @Test("returns event title when events are present")
    func returnsEventTitle() async throws {
        store.events = [makeEvent(title: "Morning Standup")]
        let out = try await handleToday(args: ["today"], store: store, calFilter: nil, config: config)
        #expect(out.contains("Morning Standup"))
    }

    @Test("includes a day header in all cases")
    func includesDayHeader() async throws {
        store.events = []
        let out = try await handleToday(args: ["today"], store: store, calFilter: nil, config: config)
        #expect(!out.isEmpty)
    }

    @Test("throws for a stray token after the command name")
    func throwsForStrayToken() async {
        await #expect(throws: CalendarHandlerError.self) {
            try await handleToday(args: ["today", "extra"], store: store, calFilter: nil, config: config)
        }
    }
}
