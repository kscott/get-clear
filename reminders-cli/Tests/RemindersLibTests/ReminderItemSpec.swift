// ReminderItemSpec.swift
//
// Tests for RemindersLib ReminderItem — the reminder value type.

import Foundation
import RemindersLib
import Testing

@Suite("ReminderItem")
struct ReminderItemTests {
    @Suite("hasRecurrenceRules")
    struct HasRecurrenceRules {
        @Test("is true when the store described a recurrence")
        func withDescription() {
            #expect(makeItem(recurrenceDescription: "weekly").hasRecurrenceRules)
        }

        @Test("is false when there is no recurrence description")
        func withoutDescription() {
            #expect(!makeItem().hasRecurrenceRules)
        }
    }

    @Suite("coding")
    struct Coding {
        @Test("an item with every field set survives a JSON round trip")
        func everyField() throws {
            let item = ReminderItem(
                identifier: "id-1",
                title: "Pay rent",
                list: ReminderList(identifier: "l-1", title: "Bills", color: "FF5733", source: "iCloud"),
                dueDateComponents: DateComponents(year: 2026, month: 12, day: 1, hour: 9, minute: 30),
                recurrenceDescription: "monthly",
                recurrenceSpec: RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: 1),
                priority: 1,
                notes: "landlord's account",
                url: URL(string: "https://example.com/pay"),
                creationDate: Date(timeIntervalSince1970: 1_790_000_000)
            )
            #expect(try jsonRoundTrip(item) == item)
        }

        @Test("an item with only the required fields survives a JSON round trip")
        func requiredOnly() throws {
            let item = makeItem()
            #expect(try jsonRoundTrip(item) == item)
        }
    }
}
