// PhoneNormalizerSpec.swift
//
// Tests for TextLib PhoneNormalizer — phone normalization, matching, formatting,
// and send target resolution.

import Quick
import Nimble
import Foundation
import TextLib

final class PhoneNormalizerSpec: QuickSpec {
    override class func spec() {
        describe("normalizePhone") {
            context("10-digit US numbers") {
                it("normalizes bare digits to E.164") {
                    expect(normalizePhone("5551234567")) == "+15551234567"
                }
                it("normalizes (555) 123-4567 format") {
                    expect(normalizePhone("(555) 123-4567")) == "+15551234567"
                }
                it("normalizes 555-123-4567 format") {
                    expect(normalizePhone("555-123-4567")) == "+15551234567"
                }
                it("normalizes 555.123.4567 format") {
                    expect(normalizePhone("555.123.4567")) == "+15551234567"
                }
            }

            context("11-digit numbers with country code") {
                it("normalizes 11 digits starting with 1") {
                    expect(normalizePhone("15551234567")) == "+15551234567"
                }
                it("normalizes 1-555-123-4567 format") {
                    expect(normalizePhone("1-555-123-4567")) == "+15551234567"
                }
            }

            context("already E.164") {
                it("leaves +1 number unchanged") {
                    expect(normalizePhone("+15551234567")) == "+15551234567"
                }
                it("strips spaces from international number") {
                    expect(normalizePhone("+44 20 7946 0958")) == "+442079460958"
                }
            }

            context("email addresses") {
                it("passes email through unchanged") {
                    expect(normalizePhone("user@example.com")) == "user@example.com"
                }
                it("passes email with + in local part through unchanged") {
                    expect(normalizePhone("user+tag@example.com")) == "user+tag@example.com"
                }
            }

            context("unrecognized input") {
                it("returns short number as-is") {
                    expect(normalizePhone("555")) == "555"
                }
                it("returns empty string as-is") {
                    expect(normalizePhone("")) == ""
                }
            }
        }

        describe("phoneMatches") {
            context("same US number in different formats") {
                it("matches E.164 to E.164") {
                    expect(phoneMatches("+15551234567", "+15551234567")) == true
                }
                it("matches E.164 to bare digits") {
                    expect(phoneMatches("+15551234567", "5551234567")) == true
                }
                it("matches formatted to E.164") {
                    expect(phoneMatches("(555) 123-4567", "+15551234567")) == true
                }
                it("matches dashes to bare digits") {
                    expect(phoneMatches("555-123-4567", "5551234567")) == true
                }
            }

            context("different numbers") {
                it("does not match different E.164 numbers") {
                    expect(phoneMatches("+15551234567", "+15559999999")) == false
                }
            }

            context("email addresses") {
                it("matches identical emails") {
                    expect(phoneMatches("user@example.com", "user@example.com")) == true
                }
                it("matches emails case-insensitively") {
                    expect(phoneMatches("USER@EXAMPLE.COM", "user@example.com")) == true
                }
                it("does not match different emails") {
                    expect(phoneMatches("alice@x.com", "bob@x.com")) == false
                }
            }

            context("partial fragments") {
                it("does not match a short fragment against a full number") {
                    expect(phoneMatches("1234", "+15551234567")) == false
                }
            }
        }

        describe("formatPhone") {
            context("US numbers") {
                it("formats E.164 to (555) 123-4567") {
                    expect(formatPhone("+15551234567")) == "(555) 123-4567"
                }
                it("formats bare digits to (555) 123-4567") {
                    expect(formatPhone("5551234567")) == "(555) 123-4567"
                }
                it("formats 11-digit with leading 1") {
                    expect(formatPhone("15551234567")) == "(555) 123-4567"
                }
            }

            context("non-US numbers") {
                it("passes international number through unchanged") {
                    expect(formatPhone("+44 20 7946 0958")) == "+44 20 7946 0958"
                }
                it("passes email through unchanged") {
                    expect(formatPhone("user@example.com")) == "user@example.com"
                }
            }
        }

        describe("resolveSendTarget") {
            let alice   = MessageContact(name: "Alice Smith",   phones: ["+15551234567"], emails: ["alice@example.com"])
            let bob     = MessageContact(name: "Bob Jones",     phones: ["(555) 999-8888"], emails: [])
            let charlie = MessageContact(name: "Charlie Brown", phones: [],                 emails: ["cbrown@peanuts.com"])
            let contacts = [alice, bob, charlie]

            context("direct input") {
                it("normalizes a phone number to E.164") {
                    expect(resolveSendTarget("5551234567", contacts: contacts)?.address) == "+15551234567"
                }
                it("uses formatted phone as display name for direct input") {
                    expect(resolveSendTarget("5551234567", contacts: contacts)?.name) == "(555) 123-4567"
                }
                it("uses an email address directly") {
                    expect(resolveSendTarget("new@person.com", contacts: contacts)?.address) == "new@person.com"
                }
            }

            context("name matching") {
                it("finds a contact by partial name") {
                    expect(resolveSendTarget("alice", contacts: contacts)?.name) == "Alice Smith"
                }
                it("uses the contact's phone as address") {
                    expect(resolveSendTarget("alice", contacts: contacts)?.address) == "+15551234567"
                }
                it("falls back to email when contact has no phone") {
                    expect(resolveSendTarget("Charlie", contacts: contacts)?.address) == "cbrown@peanuts.com"
                }
            }

            context("no match") {
                let noAddress = MessageContact(name: "Dana White", phones: [], emails: [])

                it("returns nil for an unknown name") {
                    expect(resolveSendTarget("xyzzy", contacts: contacts)).to(beNil())
                }
                it("returns nil for a contact with no phone or email") {
                    expect(resolveSendTarget("Dana", contacts: [noAddress])).to(beNil())
                }
            }
        }
    }
}
