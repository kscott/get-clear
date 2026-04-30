import CalendarLib
import Foundation
import Nimble
import Quick

final class CalendarFindHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyCalendarStore!
        let config = CalendarConfig.empty
        beforeEach { store = SpyCalendarStore() }

        describe("handleFind") {
            it("throws when no query is given") {
                await expect {
                    try await handleFind(args: ["find"], store: store, calFilter: nil, config: config)
                }.to(throwError())
            }
            it("returns 'No events matching' when nothing matches") {
                store.events = [makeEvent(title: "Team Sync")]
                let out = try await handleFind(args: ["find", "lunch"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("No events matching 'lunch'"))
            }
            it("returns event title when title matches query") {
                store.events = [makeEvent(title: "Lunch with Alice")]
                let out = try await handleFind(args: ["find", "lunch"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("Lunch with Alice"))
            }
            it("matches events whose notes contain the query") {
                store.events = [makeEvent(title: "1:1", notes: "discuss budget")]
                let out = try await handleFind(args: ["find", "budget"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("1:1"))
            }
        }
    }
}
