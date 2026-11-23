// ReminderHelperRequestSpec.swift
//
// Tests for RemindersLib ReminderHelperRequest — every case survives the wire.

import Foundation
import RemindersLib
import Testing

private let range = DateInterval(start: Date(timeIntervalSince1970: 1_790_000_000), duration: 86400)

private let everyRequest: [ReminderHelperRequest] = [
    .fetchLists,
    .defaultList,
    .fetchIncomplete(list: personalList),
    .fetchIncomplete(list: nil),
    .fetchCompleted(range: range),
    .add(makeItem(identifier: "id-1", notes: "n")),
    .complete(identifier: "id-1"),
    .rename(identifier: "id-1", title: "Pay mortgage"),
    .delete(identifier: "id-1")
]

@Suite("ReminderHelperRequest coding")
struct ReminderHelperRequestTests {
    @Test("each request survives a JSON round trip", arguments: everyRequest)
    func roundTrips(request: ReminderHelperRequest) throws {
        #expect(try jsonRoundTrip(request) == request)
    }

    @Test("an update request keeps its changes through a JSON round trip")
    func updateRoundTrips() throws {
        var opts = ParsedOptions()
        opts.priority = "high"
        let request = try ReminderHelperRequest.update(
            identifier: "id-1",
            changes: parseReminderChanges(opts, existingItem: makeItem())
        )
        #expect(try jsonRoundTrip(request) == request)
    }
}
