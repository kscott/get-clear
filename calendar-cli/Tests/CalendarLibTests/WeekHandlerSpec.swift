import CalendarLib
import Foundation
import Testing

@Suite("handleWeek")
struct WeekHandlerTests {
    let store = SpyCalendarStore()
    let config = CalendarConfig.empty

    @Test("returns 'No events this week' when store is empty")
    func noEventsThisWeek() async throws {
        store.events = []
        let out = try await handleWeek(store: store, calFilter: nil, config: config)
        #expect(out == "No events this week")
    }

    @Test("returns grouped output containing the event title")
    func groupedOutputWithTitle() async throws {
        store.events = [makeEvent(title: "Planning Session")]
        let out = try await handleWeek(store: store, calFilter: nil, config: config)
        #expect(out.contains("Planning Session"))
    }
}
