import CalendarLib
import Foundation
import Nimble
import Quick

final class CalendarRemoveHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyCalendarStore!
        let config = CalendarConfig.empty
        beforeEach { store = SpyCalendarStore() }

        describe("handleRemove") {
            it("throws when no title is given") {
                await expect {
                    try await handleRemove(args: ["remove"], store: store, calFilter: nil, config: config)
                }.to(throwError())
            }
            it("throws CalendarHandlerError when event is not found") {
                store.events = []
                await expect {
                    try await handleRemove(args: ["remove", "Nonexistent"], store: store, calFilter: nil, config: config)
                }.to(throwError { (e: CalendarHandlerError) in
                    expect(e.description).to(contain("Not found"))
                })
            }
            it("calls store.remove with the event identifier") {
                store.events = [makeEvent(identifier: "evt-99", title: "Old Meeting")]
                _ = try await handleRemove(args: ["remove", "Old Meeting"], store: store, calFilter: nil, config: config)
                expect(store.removedIds).to(contain("evt-99"))
            }
            it("returns a confirmation containing the event title") {
                store.events = [makeEvent(identifier: "evt-1", title: "Old Meeting")]
                let out = try await handleRemove(args: ["remove", "Old Meeting"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("Old Meeting"))
            }
            it("returns disambiguation message when multiple events match") {
                store.events = ambiguousEvents()
                let out = try await handleRemove(args: ["remove", "All Hands"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("Multiple events match"))
            }
        }
    }
}
