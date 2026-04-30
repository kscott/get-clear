import CalendarLib
import Foundation
import Nimble
import Quick

final class CalendarDefaultHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyCalendarStore!
        let config = CalendarConfig.empty
        beforeEach { store = SpyCalendarStore() }

        describe("handleDefault") {
            it("returns nil for a string that is not a valid range") {
                let out = try await handleDefault(args: ["change"], store: store, calFilter: nil, config: config)
                expect(out).to(beNil())
            }
            it("returns 'No events' message for a valid range with no events") {
                store.events = []
                let out = try await handleDefault(args: ["7d"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("No events"))
            }
            it("returns event output for a valid range with events") {
                store.events = [makeEvent(title: "Sprint Review")]
                let out = try await handleDefault(args: ["7d"], store: store, calFilter: nil, config: config)
                expect(out?.contains("Sprint Review")) == true
            }
        }
    }
}
