// ReminderFormatterSpec.swift
//
// Tests for ReminderFormatter — metaLine, row formatters, show output, and lookup messages.

import Foundation
import GetClearKit
import RemindersLib
import Testing

@Suite("metaLine")
struct MetaLineTests {
    @Suite("no metadata")
    struct NoMetadata {
        @Test("returns empty string for empty meta")
        func emptyForEmptyMeta() {
            #expect(metaLine(for: ReminderMeta()) == "")
        }

        @Test("returns empty string when all flags are false and priority is 0")
        func emptyWhenAllFalse() {
            #expect(
                metaLine(for: ReminderMeta(formattedDue: nil, isRepeating: false, priority: 0, hasNote: false, hasURL: false)) == ""
            )
        }
    }

    @Suite("due date")
    struct DueDate {
        @Test("includes formattedDue string when present")
        func includesFormattedDue() {
            let meta = ReminderMeta(formattedDue: "Fri Apr 11 · 3:00pm")
            #expect(metaLine(for: meta).contains("Fri Apr 11 · 3:00pm"))
        }

        @Test("returns empty string when formattedDue is nil")
        func emptyWhenNilDue() {
            #expect(metaLine(for: ReminderMeta(formattedDue: nil)) == "")
        }
    }

    @Suite("repeating")
    struct Repeating {
        @Test("includes 'repeating' when isRepeating is true")
        func includesRepeating() {
            #expect(metaLine(for: ReminderMeta(isRepeating: true)).contains("repeating"))
        }

        @Test("does not include 'repeating' when isRepeating is false")
        func noRepeatingWhenFalse() {
            #expect(metaLine(for: ReminderMeta(isRepeating: false)) == "")
        }
    }

    @Suite("priority")
    struct Priority {
        @Test("shows 'high' for priority 1") func high1() {
            #expect(metaLine(for: ReminderMeta(priority: 1)).contains("high"))
        }

        @Test("shows 'high' for priority 4") func high4() {
            #expect(metaLine(for: ReminderMeta(priority: 4)).contains("high"))
        }

        @Test("shows 'medium' for priority 5") func medium5() {
            #expect(metaLine(for: ReminderMeta(priority: 5)).contains("medium"))
        }

        @Test("shows 'low' for priority 6") func low6() {
            #expect(metaLine(for: ReminderMeta(priority: 6)).contains("low"))
        }

        @Test("shows 'low' for priority 9") func low9() {
            #expect(metaLine(for: ReminderMeta(priority: 9)).contains("low"))
        }

        @Test("shows nothing for priority 0") func none0() {
            #expect(metaLine(for: ReminderMeta(priority: 0)) == "")
        }

        @Test("shows nothing for priority 10 (out of range)") func outOfRange() {
            #expect(metaLine(for: ReminderMeta(priority: 10)) == "")
        }
    }

    @Suite("note and url")
    struct NoteAndURL {
        @Test("includes '+ note' when hasNote is true") func plusNote() {
            #expect(metaLine(for: ReminderMeta(hasNote: true)).contains("+ note"))
        }

        @Test("includes '+ url' when hasURL is true") func plusURL() {
            #expect(metaLine(for: ReminderMeta(hasURL: true)).contains("+ url"))
        }

        @Test("does not include '+ note' when hasNote is false") func noNote() {
            #expect(metaLine(for: ReminderMeta(hasNote: false)) == "")
        }

        @Test("does not include '+ url' when hasURL is false") func noURL() {
            #expect(metaLine(for: ReminderMeta(hasURL: false)) == "")
        }
    }

    @Suite("format")
    struct Format {
        @Test("starts with '  ·  ' when any field is present")
        func startsWithSeparator() {
            #expect(metaLine(for: ReminderMeta(isRepeating: true)).hasPrefix("  ·  "))
        }

        @Test("joins multiple fields with ' · '")
        func joinsMultipleFields() {
            let meta = ReminderMeta(isRepeating: true, priority: 1)
            #expect(metaLine(for: meta) == "  ·  repeating · high")
        }

        @Test("due appears before repeating")
        func dueBeforeRepeating() {
            let meta = ReminderMeta(formattedDue: "Mon Apr 14", isRepeating: true)
            #expect(metaLine(for: meta) == "  ·  Mon Apr 14 · repeating")
        }

        @Test("all fields produce correct full string")
        func allFieldsFullString() {
            let meta = ReminderMeta(
                formattedDue: "Mon Apr 14",
                isRepeating: true,
                priority: 1,
                hasNote: true,
                hasURL: true
            )
            #expect(metaLine(for: meta) == "  ·  Mon Apr 14 · repeating · high · + note · + url")
        }
    }
}

@Suite("notFoundMessage")
struct NotFoundMessageTests {
    @Test("includes the title")
    func includesTitle() {
        #expect(notFoundMessage(title: "Pay rent", list: nil).contains("Pay rent"))
    }

    @Test("does not mention a list when list is nil")
    func noListWhenNil() {
        #expect(notFoundMessage(title: "Pay rent", list: nil) == "Not found: Pay rent")
    }

    @Test("includes the list name when provided")
    func includesListName() {
        #expect(notFoundMessage(title: "Pay rent", list: "Personal") == "Not found: Pay rent in Personal")
    }
}

@Suite("disambiguationMessage")
struct DisambiguationMessageTests {
    @Test("opens with the title")
    func opensWithTitle() {
        let matches = [makeItem(), makeItem(list: workList)]
        #expect(disambiguationMessage(title: "Pay rent", matches: matches, cmd: "done")
            .hasPrefix("Multiple reminders named 'Pay rent':"))
    }

    @Test("lists each matching list title")
    func listsEachListTitle() {
        let matches = [makeItem(), makeItem(list: workList)]
        let msg = disambiguationMessage(title: "Pay rent", matches: matches, cmd: "done")
        #expect(msg.contains("[Personal]"))
        #expect(msg.contains("[Work]"))
    }

    @Test("ends with a narrowing hint including the command name")
    func narrowingHint() {
        let matches = [makeItem(), makeItem(list: workList)]
        let msg = disambiguationMessage(title: "Pay rent", matches: matches, cmd: "done")
        #expect(msg.contains("reminders done"))
        #expect(msg.contains("Personal"))
    }
}

@Suite("formatAddConfirmation")
struct FormatAddConfirmationTests {
    @Suite("title only")
    struct TitleOnly {
        @Test("includes 'Added:' prefix with title and list")
        func addedPrefix() {
            let result = formatAddConfirmation(
                title: "Pay rent", list: "Personal",
                date: nil, recurrence: nil,
                priority: "", hasNote: false, url: ""
            )
            #expect(result == "Added: Pay rent (in Personal)")
        }
    }

    @Suite("with due date")
    struct WithDueDate {
        @Test("appends due date segment")
        func appendsDueSegment() {
            let pd = ParsedDate(date: Date(timeIntervalSince1970: 0), hasTime: false, hasDate: true)
            let result = formatAddConfirmation(
                title: "Pay rent", list: "Personal",
                date: pd, recurrence: nil,
                priority: "", hasNote: false, url: ""
            )
            #expect(result.contains("due"))
        }
    }

    @Suite("with recurrence")
    struct WithRecurrence {
        @Test("appends recurrence description")
        func appendsRecurrenceDescription() {
            let spec = RecurrenceSpec(frequency: .monthly, interval: 1)
            let result = formatAddConfirmation(
                title: "Pay rent", list: "Personal",
                date: nil, recurrence: spec,
                priority: "", hasNote: false, url: ""
            )
            #expect(result.contains("repeat monthly"))
        }
    }

    @Suite("with priority")
    struct WithPriority {
        @Test("appends priority label")
        func appendsPriorityLabel() {
            let result = formatAddConfirmation(
                title: "Pay rent", list: "Personal",
                date: nil, recurrence: nil,
                priority: "high", hasNote: false, url: ""
            )
            #expect(result.contains("priority high"))
        }

        @Test("omits priority segment when priority is empty")
        func omitsPriorityWhenEmpty() {
            let result = formatAddConfirmation(
                title: "Pay rent", list: "Personal",
                date: nil, recurrence: nil,
                priority: "", hasNote: false, url: ""
            )
            #expect(!result.contains("priority"))
        }
    }

    @Suite("with note")
    struct WithNote {
        @Test("appends '+ note' when hasNote is true")
        func appendsPlusNote() {
            let result = formatAddConfirmation(
                title: "Pay rent", list: "Personal",
                date: nil, recurrence: nil,
                priority: "", hasNote: true, url: ""
            )
            #expect(result.contains("+ note"))
        }

        @Test("omits note segment when hasNote is false")
        func omitsNoteWhenFalse() {
            let result = formatAddConfirmation(
                title: "Pay rent", list: "Personal",
                date: nil, recurrence: nil,
                priority: "", hasNote: false, url: ""
            )
            #expect(!result.contains("note"))
        }
    }

    @Suite("with url")
    struct WithURL {
        @Test("appends url value")
        func appendsURLValue() {
            let result = formatAddConfirmation(
                title: "Pay rent", list: "Personal",
                date: nil, recurrence: nil,
                priority: "", hasNote: false, url: "https://example.com"
            )
            #expect(result.contains("url https://example.com"))
        }

        @Test("omits url segment when url is empty")
        func omitsURLWhenEmpty() {
            let result = formatAddConfirmation(
                title: "Pay rent", list: "Personal",
                date: nil, recurrence: nil,
                priority: "", hasNote: false, url: ""
            )
            #expect(!result.contains("url"))
        }
    }

    @Suite("all fields populated")
    struct AllFieldsPopulated {
        @Test("joins all segments with ' · '")
        func joinsAllSegments() {
            let spec = RecurrenceSpec(frequency: .weekly, interval: 1)
            let result = formatAddConfirmation(
                title: "Pay rent", list: "Personal",
                date: nil, recurrence: spec,
                priority: "high", hasNote: true, url: "https://example.com"
            )
            #expect(result.contains(" · "))
            #expect(result.contains("repeat weekly"))
            #expect(result.contains("priority high"))
            #expect(result.contains("+ note"))
            #expect(result.contains("url https://example.com"))
        }
    }
}

@Suite("formatFindRow")
struct FormatFindRowTests {
    @Test("includes the bold title")
    func includesBoldTitle() {
        #expect(formatFindRow(makeItem()).contains("Pay rent"))
    }

    @Test("includes the list title in brackets")
    func includesListInBrackets() {
        #expect(formatFindRow(makeItem()).contains("[Personal]"))
    }

    @Test("does not include a due prefix when no due date is set")
    func noDuePrefixWithoutDue() {
        #expect(!formatFindRow(makeItem()).contains("due"))
    }

    @Test("includes a due prefix when a due date is set")
    func duePrefixWithDue() {
        let comps = DateComponents(calendar: .current, year: 2026, month: 6, day: 15)
        #expect(formatFindRow(makeItem(dueDateComponents: comps)).contains("due"))
    }
}

@Suite("formatListRow")
struct FormatListRowTests {
    @Test("includes a due date in the meta when a due date is set")
    func includesDueInMeta() {
        let comps = DateComponents(calendar: .current, year: 2026, month: 6, day: 15)
        #expect(formatListRow(makeItem(dueDateComponents: comps)).contains("Jun"))
    }
}

@Suite("formatShow")
struct FormatShowTests {
    @Test("includes the title")
    func includesTitle() {
        #expect(formatShow(item: makeItem()).contains("Pay rent"))
    }

    @Test("includes the list name")
    func includesListName() {
        #expect(formatShow(item: makeItem()).contains("Personal"))
    }

    @Test("does not include a Due line when no due date is set")
    func noDueLineWithoutDue() {
        #expect(!formatShow(item: makeItem()).contains("Due:"))
    }

    @Test("includes the Due line when a due date is set")
    func dueLineWithDue() {
        let comps = DateComponents(calendar: .current, year: 2026, month: 6, day: 15)
        #expect(formatShow(item: makeItem(dueDateComponents: comps)).contains("Due:"))
    }

    @Test("includes the Repeat line when recurrenceDescription is set")
    func repeatLineWhenSet() {
        #expect(formatShow(item: makeItem(recurrenceDescription: "monthly")).contains("Repeat:   monthly"))
    }

    @Test("does not include a Repeat line when recurrenceDescription is nil")
    func noRepeatLineWhenNil() {
        #expect(!formatShow(item: makeItem()).contains("Repeat:"))
    }

    @Test("includes the Priority line for high priority")
    func priorityLineForHigh() {
        #expect(formatShow(item: makeItem(priority: 1)).contains("Priority: high"))
    }

    @Test("includes the Note line when notes is non-empty")
    func noteLineWhenNonEmpty() {
        #expect(formatShow(item: makeItem(notes: "First of month")).contains("Note:     First of month"))
    }

    @Test("does not include a Note line when notes is nil")
    func noNoteLineWhenNil() {
        #expect(!formatShow(item: makeItem()).contains("Note:"))
    }

    @Test("includes the URL line when url is set")
    func urlLineWhenSet() throws {
        let url = try #require(URL(string: "https://example.com"))
        #expect(formatShow(item: makeItem(url: url)).contains("URL:      https://example.com"))
    }
}
