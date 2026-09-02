// OptionsParsingSpec.swift
//
// Tests for OptionsParsing — mapping a ParsedCommand onto ParsedOptions.

import GetClearKit
import RemindersLib
import Testing

@Suite("parseOptions(from:)")
struct OptionsParsingTests {
    @Suite("date")
    struct DateField {
        @Test("takes the bare date when present")
        func takesBareDate() {
            let parsed = ParsedCommand(identifiers: [], bareDate: "friday", values: [:], trailingText: nil)
            #expect(parseOptions(from: parsed).date == "friday")
        }

        @Test("falls back to the due keyword's value when no bare date")
        func fallsBackToDueKeyword() {
            let parsed = ParsedCommand(identifiers: [], bareDate: nil, values: ["due": "friday"], trailingText: nil)
            #expect(parseOptions(from: parsed).date == "friday")
        }

        @Test("is empty when neither a bare date nor due is present")
        func emptyWhenAbsent() {
            let parsed = ParsedCommand(identifiers: [], bareDate: nil, values: [:], trailingText: nil)
            #expect(parseOptions(from: parsed).date == "")
        }

        @Test("passes 'due none' through as the literal string 'none'")
        func passesDueNoneThrough() {
            let parsed = ParsedCommand(identifiers: [], bareDate: nil, values: ["due": "none"], trailingText: nil)
            #expect(parseOptions(from: parsed).date == "none")
        }

        @Test("passes 'due on friday' through verbatim, unstripped")
        func passesDueOnFridayThrough() {
            let parsed = ParsedCommand(identifiers: [], bareDate: nil, values: ["due": "on friday"], trailingText: nil)
            #expect(parseOptions(from: parsed).date == "on friday")
        }
    }

    @Suite("each keyword")
    struct EachKeyword {
        @Test("recurrence comes from the repeat keyword")
        func recurrenceFromRepeat() {
            let parsed = ParsedCommand(identifiers: [], bareDate: nil, values: ["repeat": "monthly"], trailingText: nil)
            #expect(parseOptions(from: parsed).recurrence == "monthly")
        }

        @Test("priority comes from the priority keyword")
        func priorityFromKeyword() {
            let parsed = ParsedCommand(identifiers: [], bareDate: nil, values: ["priority": "high"], trailingText: nil)
            #expect(parseOptions(from: parsed).priority == "high")
        }

        @Test("url comes from the url keyword")
        func urlFromKeyword() {
            let parsed = ParsedCommand(
                identifiers: [], bareDate: nil, values: ["url": "https://example.com"], trailingText: nil
            )
            #expect(parseOptions(from: parsed).url == "https://example.com")
        }

        @Test("list comes from the list keyword")
        func listFromKeyword() {
            let parsed = ParsedCommand(identifiers: [], bareDate: nil, values: ["list": "Bills"], trailingText: nil)
            #expect(parseOptions(from: parsed).list == "Bills")
        }
    }

    @Suite("note")
    struct NoteField {
        @Test("comes from trailingText")
        func fromTrailingText() {
            let parsed = ParsedCommand(identifiers: [], bareDate: nil, values: [:], trailingText: "buy milk")
            #expect(parseOptions(from: parsed).note == "buy milk")
        }

        @Test("is empty when trailingText is nil")
        func emptyWhenAbsent() {
            let parsed = ParsedCommand(identifiers: [], bareDate: nil, values: [:], trailingText: nil)
            #expect(parseOptions(from: parsed).note == "")
        }
    }

    @Suite("all fields empty")
    struct AllFieldsEmpty {
        @Test("every field defaults to empty string for an empty ParsedCommand")
        func everyFieldEmpty() {
            let parsed = ParsedCommand(identifiers: [], bareDate: nil, values: [:], trailingText: nil)
            let opts = parseOptions(from: parsed)
            #expect(
                opts.date.isEmpty && opts.recurrence.isEmpty && opts.priority.isEmpty
                    && opts.url.isEmpty && opts.list.isEmpty && opts.note.isEmpty
            )
        }
    }
}
