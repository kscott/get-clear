// ANSISpec.swift
//
// Tests for GetClearKit ANSI — color helpers. `ANSI.enabled` reflects the real stdout tty
// state, so these assert the invariant that holds either way rather than a fixed value.

import GetClearKit
import Testing

@Suite("ANSI")
struct ANSITests {
    @Test("bold wraps in the bold escape code when enabled, or passes through unchanged")
    func boldWrapsOrPassesThrough() {
        let result = ANSI.bold("Pay rent")
        if ANSI.enabled {
            #expect(result == "\u{1B}[1mPay rent\u{1B}[0m")
        } else {
            #expect(result == "Pay rent")
        }
    }

    @Test("dim wraps in the dim escape code when enabled, or passes through unchanged")
    func dimWrapsOrPassesThrough() {
        let result = ANSI.dim("Sep 24, 2026")
        if ANSI.enabled {
            #expect(result == "\u{1B}[2mSep 24, 2026\u{1B}[0m")
        } else {
            #expect(result == "Sep 24, 2026")
        }
    }

    @Test("red wraps in the red escape code when enabled, or passes through unchanged")
    func redWrapsOrPassesThrough() {
        let result = ANSI.red("Error:")
        if ANSI.enabled {
            #expect(result == "\u{1B}[31mError:\u{1B}[0m")
        } else {
            #expect(result == "Error:")
        }
    }
}
