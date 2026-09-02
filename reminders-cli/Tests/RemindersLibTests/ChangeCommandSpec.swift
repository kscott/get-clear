// ChangeCommandSpec.swift
//
// Tests for ChangeCommand — parsePriority and parseReminderChanges.

import Foundation
import RemindersLib
import Testing

private let noItem = ReminderItem(title: "Test", list: ReminderList(title: "Reminders"))

// MARK: parsePriority

@Suite("parsePriority")
struct ParsePriorityTests {
    @Suite("recognized values")
    struct RecognizedValues {
        @Test("maps 'high' to 1") func high() {
            #expect(parsePriority("high") == 1)
        }

        @Test("maps 'medium' to 5") func medium() {
            #expect(parsePriority("medium") == 5)
        }

        @Test("maps 'med' to 5") func med() {
            #expect(parsePriority("med") == 5)
        }

        @Test("maps 'low' to 9") func low() {
            #expect(parsePriority("low") == 9)
        }

        @Test("maps 'none' to 0") func none() {
            #expect(parsePriority("none") == 0)
        }
    }

    @Suite("case insensitivity")
    struct CaseInsensitivity {
        @Test("accepts 'HIGH'") func upperHigh() {
            #expect(parsePriority("HIGH") == 1)
        }

        @Test("accepts 'Medium'") func titleMedium() {
            #expect(parsePriority("Medium") == 5)
        }

        @Test("accepts 'LOW'") func upperLow() {
            #expect(parsePriority("LOW") == 9)
        }
    }

    @Suite("unrecognized values")
    struct UnrecognizedValues {
        @Test("returns nil for empty string") func empty() {
            #expect(parsePriority("") == nil)
        }

        @Test("returns nil for unrecognized string") func unrecognized() {
            #expect(parsePriority("urgent") == nil)
        }

        @Test("returns nil for partial match") func partial() {
            #expect(parsePriority("hig") == nil)
        }
    }
}

// MARK: parseReminderChanges

@Suite("parseReminderChanges")
struct ParseReminderChangesTests {
    @Suite("empty options")
    struct EmptyOptions {
        @Test("throws nothingToChange when all fields are empty")
        func throwsNothingToChange() {
            let opts = ParsedOptions()
            #expect(throws: ReminderChangeError.nothingToChange) {
                try parseReminderChanges(opts, existingItem: noItem)
            }
        }
    }

    @Suite("due date")
    struct DueDate {
        @Test("clears due when date is 'none'")
        func clearsDueWhenNone() throws {
            var opts = ParsedOptions()
            opts.date = "none"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.due == .cleared)
        }

        @Test("adds 'due cleared' to descriptions")
        func addsDueClearedDescription() throws {
            var opts = ParsedOptions()
            opts.date = "none"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.descriptions.contains("due cleared"))
        }

        @Test("adds due date components when no existing due")
        func addsDueComponents() throws {
            var opts = ParsedOptions()
            opts.date = "2026-04-15"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            guard case let .added(comps) = changes.due else {
                Issue.record("expected .added")
                return
            }
            #expect(comps.year == 2026)
            #expect(comps.month == 4)
            #expect(comps.day == 15)
        }

        @Test("replaces due date when existing due is present")
        func replacesDueDate() throws {
            var opts = ParsedOptions()
            opts.date = "2026-05-01"
            var existing = DateComponents()
            existing.year = 2026
            existing.month = 4
            existing.day = 20
            let item = ReminderItem(title: "Test", list: ReminderList(title: "Reminders"),
                                    dueDateComponents: existing)
            let changes = try parseReminderChanges(opts, existingItem: item)
            guard case let .replaced(from, to) = changes.due else {
                Issue.record("expected .replaced")
                return
            }
            #expect(from.day == 20)
            #expect(to.day == 1)
        }

        @Test("adds 'due →' to descriptions for a recognized date")
        func addsDueArrowDescription() throws {
            var opts = ParsedOptions()
            opts.date = "2026-04-15"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.descriptions.first?.hasPrefix("due →") == true)
        }

        @Test("leaves due unchanged when date is empty")
        func leavesDueUnchanged() throws {
            var opts = ParsedOptions()
            opts.priority = "high"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.due == .unchanged)
        }

        @Test("merges time-only input with existing due date")
        func mergesTimeOnly() throws {
            var opts = ParsedOptions()
            opts.date = "3pm"
            var existing = DateComponents()
            existing.year = 2026
            existing.month = 4
            existing.day = 20
            let item = ReminderItem(title: "Test", list: ReminderList(title: "Reminders"),
                                    dueDateComponents: existing)
            let changes = try parseReminderChanges(opts, existingItem: item)
            guard case let .replaced(_, comps) = changes.due else {
                Issue.record("expected .replaced with merged components")
                return
            }
            #expect(comps.year == 2026)
            #expect(comps.month == 4)
            #expect(comps.day == 20)
            #expect(comps.hour == 15)
        }

        @Test("description includes time when merged")
        func descriptionIncludesTimeWhenMerged() throws {
            var opts = ParsedOptions()
            opts.date = "3pm"
            var existing = DateComponents()
            existing.year = 2026
            existing.month = 4
            existing.day = 20
            let item = ReminderItem(title: "Test", list: ReminderList(title: "Reminders"),
                                    dueDateComponents: existing)
            let changes = try parseReminderChanges(opts, existingItem: item)
            #expect(changes.descriptions.first?.hasPrefix("due →") == true)
        }
    }

    @Suite("recurrence")
    struct Recurrence {
        @Test("clears recurrence when value is 'none'")
        func clearsRecurrenceWhenNone() throws {
            var opts = ParsedOptions()
            opts.recurrence = "none"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            guard case .cleared = changes.recurrence else {
                Issue.record("expected .cleared")
                return
            }
        }

        @Test("adds 'repeat cleared' to descriptions")
        func addsRepeatClearedDescription() throws {
            var opts = ParsedOptions()
            opts.recurrence = "none"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.descriptions.contains("repeat cleared"))
        }

        @Test("adds recurrence when no existing recurrence")
        func addsRecurrence() throws {
            var opts = ParsedOptions()
            opts.recurrence = "weekly"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            guard case let .added(spec) = changes.recurrence else {
                Issue.record("expected .added")
                return
            }
            #expect(spec.frequency == .weekly)
        }

        @Test("replaces recurrence when existing recurrence is present")
        func replacesRecurrence() throws {
            var opts = ParsedOptions()
            opts.recurrence = "weekly"
            let existing = RecurrenceSpec(frequency: .daily, interval: 1)
            let item = ReminderItem(title: "Test", list: ReminderList(title: "Reminders"),
                                    recurrenceSpec: existing)
            let changes = try parseReminderChanges(opts, existingItem: item)
            guard case let .replaced(from, to) = changes.recurrence else {
                Issue.record("expected .replaced")
                return
            }
            #expect(from.frequency == .daily)
            #expect(to.frequency == .weekly)
        }

        @Test("throws unrecognizedRecurrence for invalid input")
        func throwsUnrecognizedRecurrence() {
            var opts = ParsedOptions()
            opts.recurrence = "garbage"
            #expect(throws: ReminderChangeError.unrecognizedRecurrence("garbage")) {
                try parseReminderChanges(opts, existingItem: noItem)
            }
        }

        @Test("leaves recurrence unchanged when empty")
        func leavesRecurrenceUnchanged() throws {
            var opts = ParsedOptions()
            opts.priority = "high"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            guard case .unchanged = changes.recurrence else {
                Issue.record("expected .unchanged")
                return
            }
        }
    }

    @Suite("priority")
    struct Priority {
        @Test("replaces priority from 0 to 1 for 'high'")
        func replacesPriorityHigh() throws {
            var opts = ParsedOptions()
            opts.priority = "high"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.priority == .replaced(from: 0, to: 1))
        }

        @Test("replaces priority to 0 for 'none'")
        func replacesPriorityNone() throws {
            var opts = ParsedOptions()
            opts.priority = "none"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.priority == .replaced(from: 0, to: 0))
        }

        @Test("carries existing priority as from value")
        func carriesExistingPriority() throws {
            var opts = ParsedOptions()
            opts.priority = "low"
            let item = ReminderItem(title: "Test", list: ReminderList(title: "Reminders"),
                                    priority: 1)
            let changes = try parseReminderChanges(opts, existingItem: item)
            #expect(changes.priority == .replaced(from: 1, to: 9))
        }

        @Test("adds 'priority → high' to descriptions")
        func addsPriorityArrowDescription() throws {
            var opts = ParsedOptions()
            opts.priority = "high"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.descriptions.contains("priority → high"))
        }

        @Test("adds 'priority cleared' when priority is none")
        func addsPriorityClearedDescription() throws {
            var opts = ParsedOptions()
            opts.priority = "none"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.descriptions.contains("priority cleared"))
        }

        @Test("leaves priority unchanged when empty")
        func leavesPriorityUnchanged() throws {
            var opts = ParsedOptions()
            opts.note = "buy milk"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.priority == .unchanged)
        }

        @Test("throws unrecognizedPriority for invalid input and applies no changes")
        func throwsUnrecognizedPriority() {
            var opts = ParsedOptions()
            opts.priority = "urgent"
            opts.note = "buy milk"
            #expect(throws: ReminderChangeError.unrecognizedPriority("urgent")) {
                try parseReminderChanges(opts, existingItem: noItem)
            }
        }

        @Test("applies a due none clear together with a priority change (SC-004)")
        func priorityAndDueNoneBothApply() throws {
            var opts = ParsedOptions()
            opts.priority = "high"
            opts.date = "none"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.priority == .replaced(from: 0, to: 1))
            #expect(changes.due == .cleared)
        }
    }

    @Suite("note")
    struct Note {
        @Test("clears note when value is 'none'")
        func clearsNoteWhenNone() throws {
            var opts = ParsedOptions()
            opts.note = "none"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.note == .cleared)
        }

        @Test("adds note when no existing note")
        func addsNote() throws {
            var opts = ParsedOptions()
            opts.note = "buy milk"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.note == .added("buy milk"))
        }

        @Test("replaces note when existing note is present")
        func replacesNote() throws {
            var opts = ParsedOptions()
            opts.note = "buy milk"
            let item = ReminderItem(title: "Test", list: ReminderList(title: "Reminders"),
                                    notes: "old note")
            let changes = try parseReminderChanges(opts, existingItem: item)
            #expect(changes.note == .replaced(from: "old note", to: "buy milk"))
        }

        @Test("adds 'note cleared' to descriptions")
        func addsNoteClearedDescription() throws {
            var opts = ParsedOptions()
            opts.note = "none"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.descriptions.contains("note cleared"))
        }

        @Test("adds '+ note' to descriptions for non-empty value")
        func addsPlusNoteDescription() throws {
            var opts = ParsedOptions()
            opts.note = "buy milk"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.descriptions.contains("+ note"))
        }
    }

    @Suite("url")
    struct URLChanges {
        @Test("clears url when value is 'none'")
        func clearsURLWhenNone() throws {
            var opts = ParsedOptions()
            opts.url = "none"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.url == .cleared)
        }

        @Test("adds url when no existing url")
        func addsURL() throws {
            var opts = ParsedOptions()
            opts.url = "https://example.com"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            let expected = try #require(URL(string: "https://example.com"))
            #expect(changes.url == .added(expected))
        }

        @Test("replaces url when existing url is present")
        func replacesURL() throws {
            var opts = ParsedOptions()
            opts.url = "https://example.com"
            let old = try #require(URL(string: "https://old.com"))
            let new = try #require(URL(string: "https://example.com"))
            let item = ReminderItem(title: "Test", list: ReminderList(title: "Reminders"),
                                    url: old)
            let changes = try parseReminderChanges(opts, existingItem: item)
            #expect(changes.url == .replaced(from: old, to: new))
        }

        @Test("adds 'url cleared' to descriptions")
        func addsURLClearedDescription() throws {
            var opts = ParsedOptions()
            opts.url = "none"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.descriptions.contains("url cleared"))
        }

        @Test("adds 'url → ...' to descriptions for non-empty value")
        func addsURLArrowDescription() throws {
            var opts = ParsedOptions()
            opts.url = "https://example.com"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.descriptions.contains("url → https://example.com"))
        }
    }

    @Suite("list")
    struct ListChanges {
        @Test("replaces list field with current list as from value")
        func replacesListField() throws {
            var opts = ParsedOptions()
            opts.list = "Work"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.list == .replaced(from: "Reminders", to: "Work"))
        }

        @Test("does not throw nothingToChange when only list is specified")
        func noThrowWhenOnlyList() {
            var opts = ParsedOptions()
            opts.list = "Work"
            #expect(throws: Never.self) { try parseReminderChanges(opts, existingItem: noItem) }
        }

        @Test("does not add list to descriptions (caller handles it)")
        func noListInDescriptions() throws {
            var opts = ParsedOptions()
            opts.list = "Work"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.descriptions.isEmpty)
        }
    }

    @Suite("multiple fields")
    struct MultipleFields {
        @Test("collects descriptions for all changed fields")
        func collectsAllDescriptions() throws {
            var opts = ParsedOptions()
            opts.priority = "high"
            opts.note = "buy milk"
            let changes = try parseReminderChanges(opts, existingItem: noItem)
            #expect(changes.descriptions.count == 2)
        }
    }
}
