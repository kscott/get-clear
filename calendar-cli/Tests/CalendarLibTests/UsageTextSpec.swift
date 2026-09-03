// UsageTextSpec.swift
//
// Tests for UsageText — the calendar --help / usage output teaches the shared argument shape.

import CalendarLib
import Testing

@Suite("usageText")
struct UsageTextTests {
    @Test("states the name-first, quoted-if-spaced rule")
    func statesNameFirstRule() {
        #expect(usageText().contains("the name comes first, quoted if it contains a space"))
    }

    @Test("states the quoting note")
    func statesQuotingNote() {
        #expect(usageText().contains("Quote every value that contains a space"))
    }

    @Test("shows quoted titles for find, show, add, and remove")
    func showsQuotedTitles() {
        let text = usageText()
        #expect(text.contains("find \"<query>\""))
        #expect(text.contains("show \"<title>\""))
        #expect(text.contains("add \"<title>\""))
        #expect(text.contains("remove \"<title>\""))
    }

    @Test("contains every command")
    func containsEveryCommand() {
        let text = usageText()
        for cmd in ["today", "week", "next", "list", "find", "show", "add", "remove", "calendars", "setup", "open"] {
            #expect(text.contains(cmd))
        }
    }
}
