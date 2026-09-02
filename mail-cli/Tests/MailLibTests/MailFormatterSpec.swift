// MailFormatterSpec.swift
//
// Tests for MailLib MailFormatter — email date and address formatting.

import Foundation
import MailLib
import Testing

@Suite("formatAddress")
struct FormatAddressTests {
    @Test("formats name and email together")
    func nameAndEmail() {
        let addr: [String: Any] = ["name": "Alice", "email": "alice@example.com"]
        #expect(formatAddress(addr) == "Alice <alice@example.com>")
    }

    @Test("returns just the email when name is empty")
    func emailWhenNameEmpty() {
        let addr: [String: Any] = ["name": "", "email": "alice@example.com"]
        #expect(formatAddress(addr) == "alice@example.com")
    }

    @Test("returns just the email when name is missing")
    func emailWhenNameMissing() {
        let addr: [String: Any] = ["email": "alice@example.com"]
        #expect(formatAddress(addr) == "alice@example.com")
    }
}

private let confAlice = AddressEntry(name: "Alice", email: "alice@example.com")
private let confBob = AddressEntry(name: "Bob", email: "bob@example.com")

@Suite("formatSendConfirmation")
struct FormatSendConfirmationTests {
    @Suite("sent, no cc, no subject")
    struct SentNoCcNoSubject {
        @Test("returns a sent confirmation with bold recipient")
        func sentConfirmationWithRecipient() {
            let result = formatSendConfirmation(to: "alice@example.com", cc: [], subject: "", isDraft: false)
            #expect(result.contains("alice@example.com"))
        }
    }

    @Suite("sent with subject")
    struct SentWithSubject {
        @Test("includes the subject")
        func includesSubject() {
            let result = formatSendConfirmation(to: "alice@example.com", cc: [], subject: "Lunch?", isDraft: false)
            #expect(result.contains("Lunch?"))
        }
    }

    @Suite("sent with cc")
    struct SentWithCc {
        @Test("includes the cc recipient")
        func includesCcRecipient() {
            let result = formatSendConfirmation(to: "alice@example.com", cc: [confBob], subject: "", isDraft: false)
            #expect(result.contains("bob@example.com"))
        }

        @Test("includes multiple cc recipients")
        func includesMultipleCcRecipients() {
            let result = formatSendConfirmation(to: "alice@example.com", cc: [confAlice, confBob], subject: "", isDraft: false)
            #expect(result.contains("Alice"))
            #expect(result.contains("Bob"))
        }
    }

    @Suite("draft")
    struct Draft {
        @Test("says Saved draft")
        func saysSavedDraft() {
            let result = formatSendConfirmation(to: "alice@example.com", cc: [], subject: "", isDraft: true)
            #expect(result.contains("draft"))
        }

        @Test("includes the subject in a draft confirmation")
        func includesSubjectInDraft() {
            let result = formatSendConfirmation(to: "alice@example.com", cc: [], subject: "Re: Lunch", isDraft: true)
            #expect(result.contains("Re: Lunch"))
        }
    }
}

@Suite("formatAddresses")
struct FormatAddressesTests {
    @Test("joins multiple addresses with commas")
    func joinsWithCommas() {
        let addrs: [[String: Any]] = [
            ["name": "Alice", "email": "alice@example.com"],
            ["name": "Bob", "email": "bob@example.com"]
        ]
        #expect(formatAddresses(addrs) == "Alice <alice@example.com>, Bob <bob@example.com>")
    }

    @Test("returns empty string for empty list")
    func emptyForEmptyList() {
        #expect(formatAddresses([]) == "")
    }
}

@Suite("leftPad")
struct LeftPadTests {
    @Test("pads a short string to the specified width")
    func padsShortString() {
        #expect("5".leftPad(3) == "  5")
    }

    @Test("does not truncate a string that is already at width")
    func noTruncateAtWidth() {
        #expect("123".leftPad(3) == "123")
    }

    @Test("does not truncate a string that exceeds width")
    func noTruncateOverWidth() {
        #expect("12345".leftPad(3) == "12345")
    }
}

@Suite("formatDate")
struct FormatDateTests {
    @Suite("a date with fractional seconds in the current year")
    struct FractionalSecondsCurrentYear {
        @Test("returns a short month-day string, not the raw ISO input")
        func notRawISO() {
            let iso = "2026-04-13T14:30:00.000Z"
            #expect(formatDate(iso) != iso)
        }
    }

    @Suite("today's date")
    struct TodaysDate {
        @Test("returns a time string (h:mma) for a date that is today")
        func timeStringForToday() {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let result = formatDate(fmt.string(from: Date()))
            #expect(result.contains(":"))
        }
    }

    @Suite("a date in a past year")
    struct PastYear {
        @Test("returns a string containing the year")
        func containsYear() {
            #expect(formatDate("2020-06-15T10:00:00Z").contains("2020"))
        }
    }

    @Suite("an unparseable string")
    struct UnparseableString {
        @Test("returns the raw string unchanged")
        func rawUnchanged() {
            #expect(formatDate("not-a-date") == "not-a-date")
        }
    }
}

@Suite("formatDateLong")
struct FormatDateLongTests {
    @Suite("a valid date")
    struct ValidDate {
        @Test("returns a formatted string, not the raw ISO input")
        func notRawISO() {
            #expect(formatDateLong("2026-04-13T14:30:00.000Z") != "2026-04-13T14:30:00.000Z")
        }
    }

    @Suite("an unparseable string")
    struct UnparseableString {
        @Test("returns the raw string unchanged")
        func rawUnchanged() {
            #expect(formatDateLong("not-a-date") == "not-a-date")
        }
    }
}
