import CalendarLib
import Foundation
import Testing

@Suite("handleCalendars")
struct CalendarsHandlerTests {
    let store = SpyCalendarStore()

    @Test("returns calendar titles grouped by source")
    func returnsTitlesGroupedBySource() async throws {
        store.calendars = [workCal, personalCal]
        let out = try await handleCalendars(store: store)
        #expect(out.contains("Work"))
        #expect(out.contains("Personal"))
    }

    @Test("returns empty string when no calendars exist")
    func emptyWhenNoCalendars() async throws {
        store.calendars = []
        let out = try await handleCalendars(store: store)
        #expect(out == "")
    }

    @Test("groups calendars under their source heading")
    func groupsUnderSourceHeading() async throws {
        store.calendars = [workCal, personalCal]
        let out = try await handleCalendars(store: store)
        #expect(out.contains("iCloud"))
    }
}
