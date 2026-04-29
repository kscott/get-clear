import Quick
import Nimble
import Foundation
import CalendarLib

final class CalendarNextHandlerSpec: AsyncSpec {
    override class func spec() {

        var store: SpyCalendarStore!
        let config = CalendarConfig.empty
        beforeEach { store = SpyCalendarStore() }

        describe("handleNext") {
            it("returns 'No upcoming events' when store is empty") {
                store.events = []
                let out = try await handleNext(args: ["next"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("No upcoming events"))
            }
            it("returns event title for upcoming events") {
                store.events = [makeEvent(title: "Quarterly Review", dayOffset: 1)]
                let out = try await handleNext(args: ["next"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("Quarterly Review"))
            }
            it("defaults to 5 events when no count argument is given") {
                store.events = (1...10).map { makeEvent(identifier: "e\($0)", title: "Event \($0)", dayOffset: $0) }
                let out   = try await handleNext(args: ["next"], store: store, calFilter: nil, config: config)
                let lines = out.components(separatedBy: "\n").filter { !$0.isEmpty }
                expect(lines.count) == 5
            }
            it("respects a custom count argument") {
                store.events = (1...10).map { makeEvent(identifier: "e\($0)", title: "Event \($0)", dayOffset: $0) }
                let out   = try await handleNext(args: ["next", "3"], store: store, calFilter: nil, config: config)
                let lines = out.components(separatedBy: "\n").filter { !$0.isEmpty }
                expect(lines.count) == 3
            }
            it("appends location to the event line when present") {
                store.events = [makeEvent(title: "Offsite", dayOffset: 1, location: "Building 2")]
                let out = try await handleNext(args: ["next"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("Building 2"))
            }
        }
    }
}
