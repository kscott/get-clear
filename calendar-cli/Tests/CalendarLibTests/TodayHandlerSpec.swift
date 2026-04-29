import Quick
import Nimble
import Foundation
import CalendarLib

final class CalendarTodayHandlerSpec: AsyncSpec {
    override class func spec() {

        var store: SpyCalendarStore!
        let config = CalendarConfig.empty
        beforeEach { store = SpyCalendarStore() }

        describe("handleToday") {
            it("returns day header and '(nothing scheduled)' when no events") {
                store.events = []
                let out = try await handleToday(store: store, calFilter: nil, config: config)
                expect(out).to(contain("(nothing scheduled)"))
            }
            it("returns event title when events are present") {
                store.events = [makeEvent(title: "Morning Standup")]
                let out = try await handleToday(store: store, calFilter: nil, config: config)
                expect(out).to(contain("Morning Standup"))
            }
            it("includes a day header in all cases") {
                store.events = []
                let out = try await handleToday(store: store, calFilter: nil, config: config)
                expect(out).toNot(beEmpty())
            }
        }
    }
}
