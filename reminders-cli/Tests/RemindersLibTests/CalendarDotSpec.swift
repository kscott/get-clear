// CalendarDotSpec.swift

import Quick
import Nimble
import RemindersLib

final class CalendarDotSpec: QuickSpec {
    override class func spec() {

        describe("calendarDot") {

            context("when ANSI is disabled") {
                it("returns two spaces regardless of hex value") {
                    expect(calendarDot(hex: "FF5733", ansiEnabled: false)) == "  "
                }
                it("returns two spaces when hex is nil") {
                    expect(calendarDot(hex: nil, ansiEnabled: false)) == "  "
                }
            }

            context("when ANSI is enabled") {
                it("returns an ANSI colored dot for a valid hex color") {
                    let result = calendarDot(hex: "FF5733", ansiEnabled: true)
                    expect(result).to(contain("●"))
                    expect(result).to(contain("\u{001B}[38;2;255;87;51m"))
                }
                it("returns two spaces for nil hex") {
                    expect(calendarDot(hex: nil, ansiEnabled: true)) == "  "
                }
                it("returns two spaces for a hex string shorter than 6 characters") {
                    expect(calendarDot(hex: "FF57", ansiEnabled: true)) == "  "
                }
                it("returns two spaces for an invalid hex string") {
                    expect(calendarDot(hex: "GGGGGG", ansiEnabled: true)) == "  "
                }
            }
        }

    }
}
