import CalendarLib
import Foundation
import Nimble
import Quick

final class CalendarShowHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyCalendarStore!
        let config = CalendarConfig.empty
        beforeEach { store = SpyCalendarStore() }

        describe("handleShow") {
            it("throws when no title is given") {
                await expect {
                    try await handleShow(args: ["show"], store: store, calFilter: nil, config: config)
                }.to(throwError())
            }
            it("throws CalendarHandlerError when event is not found") {
                store.events = []
                await expect {
                    try await handleShow(args: ["show", "Nonexistent"], store: store, calFilter: nil, config: config)
                }.to(throwError { (e: CalendarHandlerError) in
                    expect(e.description).to(contain("Not found"))
                })
            }
            it("returns event title in output when found") {
                store.events = [makeEvent(title: "Board Meeting")]
                let out = try await handleShow(args: ["show", "Board Meeting"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("Board Meeting"))
            }
            it("returns calendar name in output") {
                store.events = [makeEvent(title: "Board Meeting", calendarTitle: "Work")]
                let out = try await handleShow(args: ["show", "Board Meeting"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("Work"))
            }
            it("returns location when present") {
                store.events = [makeEvent(title: "Offsite", location: "Conference Room A")]
                let out = try await handleShow(args: ["show", "Offsite"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("Conference Room A"))
            }
            it("returns attendees with their status when present") {
                let attendees = [AttendeeItem(name: "Alice", status: "accepted")]
                store.events = [makeEvent(title: "Review", attendees: attendees)]
                let out = try await handleShow(args: ["show", "Review"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("Alice (accepted)"))
            }
            it("returns disambiguation message when multiple events match") {
                store.events = ambiguousEvents(title: "All Hands")
                let out = try await handleShow(args: ["show", "All Hands"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("Multiple events match"))
            }
            it("omits location line when location is nil") {
                store.events = [makeEvent(title: "No-loc Event", location: nil)]
                let out = try await handleShow(args: ["show", "No-loc Event"], store: store, calFilter: nil, config: config)
                expect(out).toNot(contain("Location:"))
            }
            it("includes 'all day' in the date line for all-day events") {
                store.events = [makeEvent(title: "Holiday", isAllDay: true)]
                let out = try await handleShow(args: ["show", "Holiday"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("all day"))
            }
            it("includes notes in output when present") {
                store.events = [makeEvent(title: "Planning", notes: "Review Q2 goals")]
                let out = try await handleShow(args: ["show", "Planning"], store: store, calFilter: nil, config: config)
                expect(out).to(contain("Review Q2 goals"))
            }
        }
    }
}
