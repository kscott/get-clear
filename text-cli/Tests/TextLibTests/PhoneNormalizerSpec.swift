// PhoneNormalizerSpec.swift
// Tests for TextLib PhoneNormalizer — phone normalization and display formatting.

import Foundation
import Nimble
import Quick
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
    }
}
