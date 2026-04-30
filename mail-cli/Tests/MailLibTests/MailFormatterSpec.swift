// MailFormatterSpec.swift
//
// Tests for MailLib MailFormatter — email date and address formatting.

import Quick
import Nimble
import Foundation
import MailLib

final class MailFormatterSpec: QuickSpec {
    override class func spec() {
        describe("formatAddress") {
            it("formats name and email together") {
                let addr: [String: Any] = ["name": "Ken Scott", "email": "ken@optikos.net"]
                expect(formatAddress(addr)) == "Ken Scott <ken@optikos.net>"
            }

            it("returns just the email when name is empty") {
                let addr: [String: Any] = ["name": "", "email": "ken@optikos.net"]
                expect(formatAddress(addr)) == "ken@optikos.net"
            }

            it("returns just the email when name is missing") {
                let addr: [String: Any] = ["email": "ken@optikos.net"]
                expect(formatAddress(addr)) == "ken@optikos.net"
            }
        }

        describe("formatSendConfirmation") {
            let alice = AddressEntry(name: "Alice", email: "alice@example.com")
            let bob   = AddressEntry(name: "Bob",   email: "bob@example.com")

            context("sent, no cc, no subject") {
                it("returns a sent confirmation with bold recipient") {
                    let result = formatSendConfirmation(to: "alice@example.com", cc: [], subject: "", isDraft: false)
                    expect(result).to(contain("alice@example.com"))
                }
            }
            context("sent with subject") {
                it("includes the subject") {
                    let result = formatSendConfirmation(to: "alice@example.com", cc: [], subject: "Lunch?", isDraft: false)
                    expect(result).to(contain("Lunch?"))
                }
            }
            context("sent with cc") {
                it("includes the cc recipient") {
                    let result = formatSendConfirmation(to: "alice@example.com", cc: [bob], subject: "", isDraft: false)
                    expect(result).to(contain("bob@example.com"))
                }
                it("includes multiple cc recipients") {
                    let result = formatSendConfirmation(to: "alice@example.com", cc: [alice, bob], subject: "", isDraft: false)
                    expect(result).to(contain("Alice"))
                    expect(result).to(contain("Bob"))
                }
            }
            context("draft") {
                it("says Saved draft") {
                    let result = formatSendConfirmation(to: "alice@example.com", cc: [], subject: "", isDraft: true)
                    expect(result).to(contain("draft"))
                }
                it("includes the subject in a draft confirmation") {
                    let result = formatSendConfirmation(to: "alice@example.com", cc: [], subject: "Re: Lunch", isDraft: true)
                    expect(result).to(contain("Re: Lunch"))
                }
            }
        }

        describe("formatAddresses") {
            it("joins multiple addresses with commas") {
                let addrs: [[String: Any]] = [
                    ["name": "Alice", "email": "alice@example.com"],
                    ["name": "Bob",   "email": "bob@example.com"],
                ]
                expect(formatAddresses(addrs)) == "Alice <alice@example.com>, Bob <bob@example.com>"
            }

            it("returns empty string for empty list") {
                expect(formatAddresses([])) == ""
            }
        }

        describe("leftPad") {
            it("pads a short string to the specified width") {
                expect("5".leftPad(3)) == "  5"
            }

            it("does not truncate a string that is already at width") {
                expect("123".leftPad(3)) == "123"
            }

            it("does not truncate a string that exceeds width") {
                expect("12345".leftPad(3)) == "12345"
            }
        }

        describe("formatDate") {
            context("a date with fractional seconds in the current year") {
                it("returns a short month-day string, not the raw ISO input") {
                    let iso = "2026-04-13T14:30:00.000Z"
                    expect(formatDate(iso)) != iso
                }
            }

            context("today's date") {
                it("returns a time string (h:mma) for a date that is today") {
                    let fmt = ISO8601DateFormatter()
                    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let result = formatDate(fmt.string(from: Date()))
                    expect(result).to(contain(":"))
                }
            }

            context("a date in a past year") {
                it("returns a string containing the year") {
                    expect(formatDate("2020-06-15T10:00:00Z")).to(contain("2020"))
                }
            }

            context("an unparseable string") {
                it("returns the raw string unchanged") {
                    expect(formatDate("not-a-date")) == "not-a-date"
                }
            }
        }

        describe("formatDateLong") {
            context("a valid date") {
                it("returns a formatted string, not the raw ISO input") {
                    expect(formatDateLong("2026-04-13T14:30:00.000Z")) != "2026-04-13T14:30:00.000Z"
                }
            }

            context("an unparseable string") {
                it("returns the raw string unchanged") {
                    expect(formatDateLong("not-a-date")) == "not-a-date"
                }
            }
        }
    }
}
