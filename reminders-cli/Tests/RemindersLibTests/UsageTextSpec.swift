// UsageTextSpec.swift
//
// Tests for UsageText — the reminders --help / usage output teaches the shared argument shape.

import RemindersLib
import Testing

@Suite("usageText")
struct UsageTextTests {
    @Test("states the name-first, quoted-if-spaced rule")
    func statesNameFirstRule() {
        #expect(usageText().contains("The name comes first, quoted if it contains a space"))
    }

    @Test("states the due-date rule")
    func statesDueDateRule() {
        #expect(usageText().contains("A due date is either bare right after the name or introduced by"))
    }

    @Test("states the keyword-value rule")
    func statesKeywordValueRule() {
        #expect(usageText().contains("Everything else is \"keyword value\", in any order"))
    }

    @Test("states the quoting note")
    func statesQuotingNote() {
        #expect(usageText().contains("Quoting: quote every value that contains a space"))
    }

    @Test("shows list as a keyword with a quoted name, not a bare positional")
    func showsListAsKeyword() {
        #expect(usageText().contains("list \"<name>\""))
    }

    @Test("does not show a bare [list] positional")
    func noBareListPositional() {
        #expect(!usageText().contains("[list]"))
    }

    @Test("shows the note example quoted")
    func showsNoteQuoted() {
        #expect(usageText().contains("note \"your free text goes here to end of line\""))
    }
}
