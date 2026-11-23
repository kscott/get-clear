// CalendarHelperRequestSpec.swift
//
// Tests for CalendarLib CalendarHelperRequest — every case survives the wire.

import CalendarLib
import Foundation
import Testing

private let range = DateInterval(start: Date(timeIntervalSince1970: 1_790_000_000), duration: 86400)

private let everyRequest: [CalendarHelperRequest] = [
    .fetchCalendars,
    .fetchEvents(range: range, calendarIdentifiers: ["id-work"]),
    .fetchEvents(range: range, calendarIdentifiers: nil),
    .add(makeEvent(title: "All Hands")),
    .remove(identifier: "e-1")
]

@Suite("CalendarHelperRequest coding")
struct CalendarHelperRequestTests {
    @Test("each request survives a JSON round trip", arguments: everyRequest)
    func roundTrips(request: CalendarHelperRequest) throws {
        let decoded = try JSONDecoder().decode(CalendarHelperRequest.self, from: JSONEncoder().encode(request))
        #expect(decoded == request)
    }
}
