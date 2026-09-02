// CalendarDotSpec.swift

import GetClearKit
import Testing

@Suite("calendarDot")
struct CalendarDotTests {
    @Suite("when ANSI is disabled")
    struct AnsiDisabled {
        @Test("returns two spaces regardless of hex value")
        func twoSpacesForAnyHex() {
            #expect(calendarDot(hex: "FF5733", ansiEnabled: false) == "  ")
        }

        @Test("returns two spaces when hex is nil")
        func twoSpacesForNilHex() {
            #expect(calendarDot(hex: nil, ansiEnabled: false) == "  ")
        }
    }

    @Suite("when ANSI is enabled")
    struct AnsiEnabled {
        @Test("returns an ANSI colored dot for a valid hex color")
        func coloredDotForValidHex() {
            let result = calendarDot(hex: "FF5733", ansiEnabled: true)
            #expect(result.contains("●"))
            #expect(result.contains("\u{001B}[38;2;255;87;51m"))
        }

        @Test("returns two spaces for nil hex")
        func twoSpacesForNilHex() {
            #expect(calendarDot(hex: nil, ansiEnabled: true) == "  ")
        }

        @Test("returns two spaces for a hex string shorter than 6 characters")
        func twoSpacesForShortHex() {
            #expect(calendarDot(hex: "FF57", ansiEnabled: true) == "  ")
        }

        @Test("returns two spaces for an invalid hex string")
        func twoSpacesForInvalidHex() {
            #expect(calendarDot(hex: "GGGGGG", ansiEnabled: true) == "  ")
        }
    }
}
