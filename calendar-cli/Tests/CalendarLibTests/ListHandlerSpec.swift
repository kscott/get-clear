import CalendarLib
import Foundation
import Nimble
import Quick

final class CalendarListHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyCalendarStore!
        let config = CalendarConfig.empty
        beforeEach { store = SpyCalendarStore() }

        describe("handleList") {
            it("throws when no range argument is given") {
                await expect {
                    try await handleList(args: ["list"], store: store, calFilter: nil, config: config)
                }.to(throwError())
            }
            it("throws for an unrecognised range string") {
                await expect {
                    try await handleList(args: ["list", "notarange"], store: store, calFilter: nil, config: config)
                }.to(throwError())
            }
            it("returns 'No events' message when store is empty") {
                store.events = []
                let out = try await handleList(args: ["list", "7d"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("No events"))
            }
            it("returns event title when events exist") {
                store.events = [makeEvent(title: "Sprint Review")]
                let out = try await handleList(args: ["list", "7d"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("Sprint Review"))
            }
            it("returns grouped output for a multi-day range") {
                store.events = [makeEvent(title: "Day 1"), makeEvent(title: "Day 2", dayOffset: 3)]
                let out = try await handleList(args: ["list", "7d"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("Day 1"))
                expect(out).to(contain("Day 2"))
            }
        }
    }
}
