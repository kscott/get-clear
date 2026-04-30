import CalendarLib
import Foundation
import Nimble
import Quick

final class CalendarStoreSpec: AsyncSpec {
    override class func spec() {
        var store: SpyCalendarStore!
        let range = DateInterval(start: Date(), duration: 86400)

        beforeEach { store = SpyCalendarStore() }

        describe("resolve") {
            context("exact title match") {
                it("returns the matching event") {
                    store.events = [makeEvent(identifier: "evt-1", title: "Team Sync")]
                    let event = try await store.resolve(title: "Team Sync", in: range, calendarIdentifiers: nil)
                    expect(event.identifier) == "evt-1"
                }
            }
            context("case-insensitive contains match") {
                it("returns the event when the title contains the search string") {
                    store.events = [makeEvent(title: "All Hands Meeting")]
                    let event = try await store.resolve(title: "all hands", in: range, calendarIdentifiers: nil)
                    expect(event.title) == "All Hands Meeting"
                }
            }
            context("not found") {
                it("throws notFound when no events match") {
                    store.events = [makeEvent(title: "Team Sync")]
                    await expect {
                        try await store.resolve(title: "Nonexistent", in: range, calendarIdentifiers: nil)
                    }.to(throwError(CalendarStoreError.notFound("Nonexistent")))
                }
            }
            context("ambiguous") {
                it("throws ambiguous when multiple events match") {
                    store.events = ambiguousEvents(title: "All Hands")
                    await expect {
                        try await store.resolve(title: "All Hands", in: range, calendarIdentifiers: nil)
                    }.to(throwError { (e: CalendarStoreError) in
                        if case let .ambiguous(matches) = e { expect(matches.count) == 2 } else { fail("expected ambiguous error") }
                    })
                }
            }
        }
    }
}
