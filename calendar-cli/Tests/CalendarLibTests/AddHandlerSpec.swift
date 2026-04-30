import CalendarLib
import Foundation
import Nimble
import Quick

final class CalendarAddHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyCalendarStore!
        let config = CalendarConfig.empty
        beforeEach { store = SpyCalendarStore() }

        describe("handleAdd") {
            it("throws when no title is given") {
                await expect {
                    try await handleAdd(args: ["add"], store: store, calFilter: nil, config: config)
                }.to(throwError())
            }
            it("throws for an unrecognised date/time string") {
                await expect {
                    try await handleAdd(args: ["add", "Meeting", "notadate"], store: store, calFilter: nil, config: config)
                }.to(throwError())
            }
            it("calls store.add with the correct event title") {
                _ = try await handleAdd(args: ["add", "Sprint Planning", "tomorrow 10am"], store: store, calFilter: nil, config: config)
                expect(store.addedItems.first?.title) == "Sprint Planning"
            }
            it("returns a confirmation containing the event title") {
                let out = try await handleAdd(
                    args: ["add", "Sprint Planning", "tomorrow 10am"],
                    store: store,
                    calFilter: nil,
                    config: config
                )
                expect(out).to(contain("Sprint Planning"))
            }
            it("defaults to today when no date is given") {
                _ = try await handleAdd(args: ["add", "Quick Check"], store: store, calFilter: nil, config: config)
                expect(store.addedItems.first?.title) == "Quick Check"
            }
            it("sets all-day flag for a date-only input") {
                _ = try await handleAdd(args: ["add", "Holiday", "april 30"], store: store, calFilter: nil, config: config)
                expect(store.addedItems.first?.isAllDay) == true
            }
            it("clears all-day flag for a timed input") {
                _ = try await handleAdd(args: ["add", "Meeting", "tomorrow 2pm"], store: store, calFilter: nil, config: config)
                expect(store.addedItems.first?.isAllDay) == false
            }
        }
    }
}
