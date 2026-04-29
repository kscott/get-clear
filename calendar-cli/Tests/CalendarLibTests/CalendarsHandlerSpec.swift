import Quick
import Nimble
import Foundation
import CalendarLib

final class CalendarsHandlerSpec: AsyncSpec {
    override class func spec() {

        var store: SpyCalendarStore!
        beforeEach { store = SpyCalendarStore() }

        describe("handleCalendars") {
            it("returns calendar titles grouped by source") {
                store.calendars = [workCal, personalCal]
                let out = try await handleCalendars(store: store)
                expect(out).to(contain("Work"))
                expect(out).to(contain("Personal"))
            }
            it("returns empty string when no calendars exist") {
                store.calendars = []
                let out = try await handleCalendars(store: store)
                expect(out) == ""
            }
            it("groups calendars under their source heading") {
                store.calendars = [workCal, personalCal]
                let out = try await handleCalendars(store: store)
                expect(out).to(contain("iCloud"))
            }
        }
    }
}
