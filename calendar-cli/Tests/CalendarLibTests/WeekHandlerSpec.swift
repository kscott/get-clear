import CalendarLib
import Foundation
import Nimble
import Quick

final class CalendarWeekHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyCalendarStore!
        let config = CalendarConfig.empty
        beforeEach { store = SpyCalendarStore() }

        describe("handleWeek") {
            it("returns 'No events this week' when store is empty") {
                store.events = []
                let out = try await handleWeek(store: store, calFilter: nil, config: config)
                expect(out) == "No events this week"
            }
            it("returns grouped output containing the event title") {
                store.events = [makeEvent(title: "Planning Session")]
                let out = try await handleWeek(store: store, calFilter: nil, config: config)
                expect(out).to(contain("Planning Session"))
            }
        }
    }
}
