// PhoneNormalizerSpec.swift
// Tests for TextLib PhoneNormalizer — phone normalization and display formatting.

import Foundation
import Testing
import TextLib

@Suite("normalizePhone")
struct NormalizePhoneTests {
    @Suite("10-digit US numbers")
    struct TenDigitUS {
        @Test("normalizes bare digits to E.164")
        func bareDigits() {
            #expect(normalizePhone("5551234567") == "+15551234567")
        }

        @Test("normalizes (555) 123-4567 format")
        func parenFormat() {
            #expect(normalizePhone("(555) 123-4567") == "+15551234567")
        }

        @Test("normalizes 555-123-4567 format")
        func dashFormat() {
            #expect(normalizePhone("555-123-4567") == "+15551234567")
        }

        @Test("normalizes 555.123.4567 format")
        func dotFormat() {
            #expect(normalizePhone("555.123.4567") == "+15551234567")
        }
    }

    @Suite("11-digit numbers with country code")
    struct ElevenDigit {
        @Test("normalizes 11 digits starting with 1")
        func elevenDigits() {
            #expect(normalizePhone("15551234567") == "+15551234567")
        }

        @Test("normalizes 1-555-123-4567 format")
        func elevenDashFormat() {
            #expect(normalizePhone("1-555-123-4567") == "+15551234567")
        }
    }

    @Suite("already E.164")
    struct AlreadyE164 {
        @Test("leaves +1 number unchanged")
        func plusOneUnchanged() {
            #expect(normalizePhone("+15551234567") == "+15551234567")
        }

        @Test("strips spaces from international number")
        func stripsInternationalSpaces() {
            #expect(normalizePhone("+44 20 7946 0958") == "+442079460958")
        }
    }

    @Suite("email addresses")
    struct EmailAddresses {
        @Test("passes email through unchanged")
        func emailUnchanged() {
            #expect(normalizePhone("user@example.com") == "user@example.com")
        }

        @Test("passes email with + in local part through unchanged")
        func emailPlusUnchanged() {
            #expect(normalizePhone("user+tag@example.com") == "user+tag@example.com")
        }
    }

    @Suite("unrecognized input")
    struct UnrecognizedInput {
        @Test("returns short number as-is")
        func shortNumberAsIs() {
            #expect(normalizePhone("555") == "555")
        }

        @Test("returns empty string as-is")
        func emptyStringAsIs() {
            #expect(normalizePhone("") == "")
        }
    }
}

@Suite("formatPhone")
struct FormatPhoneTests {
    @Suite("US numbers")
    struct USNumbers {
        @Test("formats E.164 to (555) 123-4567")
        func formatsE164() {
            #expect(formatPhone("+15551234567") == "(555) 123-4567")
        }

        @Test("formats bare digits to (555) 123-4567")
        func formatsBareDigits() {
            #expect(formatPhone("5551234567") == "(555) 123-4567")
        }

        @Test("formats 11-digit with leading 1")
        func formatsElevenDigit() {
            #expect(formatPhone("15551234567") == "(555) 123-4567")
        }
    }

    @Suite("non-US numbers")
    struct NonUSNumbers {
        @Test("passes international number through unchanged")
        func internationalUnchanged() {
            #expect(formatPhone("+44 20 7946 0958") == "+44 20 7946 0958")
        }

        @Test("passes email through unchanged")
        func emailUnchanged() {
            #expect(formatPhone("user@example.com") == "user@example.com")
        }
    }
}
