// ChangeCommandSpec.swift
//
// Tests for ChangeCommand — parsePriority and parseReminderChanges.

import Quick
import Nimble
import Foundation
import RemindersLib

final class ChangeCommandSpec: QuickSpec {
    override class func spec() {

        let noItem = ReminderItem(title: "Test", list: ReminderList(title: "Reminders"))

        // MARK: parsePriority

        describe("parsePriority") {
            context("recognized values") {
                it("maps 'high' to 1") { expect(parsePriority("high")) == 1 }
                it("maps 'medium' to 5") { expect(parsePriority("medium")) == 5 }
                it("maps 'med' to 5") { expect(parsePriority("med")) == 5 }
                it("maps 'low' to 9") { expect(parsePriority("low")) == 9 }
                it("maps 'none' to 0") { expect(parsePriority("none")) == 0 }
            }
            context("case insensitivity") {
                it("accepts 'HIGH'") { expect(parsePriority("HIGH")) == 1 }
                it("accepts 'Medium'") { expect(parsePriority("Medium")) == 5 }
                it("accepts 'LOW'") { expect(parsePriority("LOW")) == 9 }
            }
            context("unrecognized values") {
                it("returns nil for empty string") { expect(parsePriority("")) == nil }
                it("returns nil for unrecognized string") { expect(parsePriority("urgent")) == nil }
                it("returns nil for partial match") { expect(parsePriority("hig")) == nil }
            }
        }

        // MARK: parseReminderChanges

        describe("parseReminderChanges") {

            context("empty options") {
                it("throws nothingToChange when all fields are empty") {
                    let opts = ParsedOptions()
                    expect { try parseReminderChanges(opts, existingItem: noItem) }
                        .to(throwError(ReminderChangeError.nothingToChange))
                }
            }

            context("due date") {
                it("clears due when date is 'none'") {
                    var opts = ParsedOptions(); opts.date = "none"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.due) == .cleared
                }
                it("adds 'due cleared' to descriptions") {
                    var opts = ParsedOptions(); opts.date = "none"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.descriptions).to(contain("due cleared"))
                }
                it("adds due date components when no existing due") {
                    var opts = ParsedOptions(); opts.date = "2026-04-15"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    if case .added(let comps) = changes.due {
                        expect(comps.year) == 2026
                        expect(comps.month) == 4
                        expect(comps.day) == 15
                    } else {
                        fail("expected .added")
                    }
                }
                it("replaces due date when existing due is present") {
                    var opts = ParsedOptions(); opts.date = "2026-05-01"
                    var existing = DateComponents()
                    existing.year = 2026; existing.month = 4; existing.day = 20
                    let item = ReminderItem(title: "Test", list: ReminderList(title: "Reminders"),
                                           dueDateComponents: existing)
                    let changes = try! parseReminderChanges(opts, existingItem: item)
                    if case .replaced(let from, let to) = changes.due {
                        expect(from.day) == 20
                        expect(to.day) == 1
                    } else {
                        fail("expected .replaced")
                    }
                }
                it("adds 'due →' to descriptions for a recognized date") {
                    var opts = ParsedOptions(); opts.date = "2026-04-15"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.descriptions.first).to(beginWith("due →"))
                }
                it("leaves due unchanged when date is empty") {
                    var opts = ParsedOptions(); opts.priority = "high"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.due) == .unchanged
                }
                it("merges time-only input with existing due date") {
                    var opts = ParsedOptions(); opts.date = "3pm"
                    var existing = DateComponents()
                    existing.year = 2026; existing.month = 4; existing.day = 20
                    let item = ReminderItem(title: "Test", list: ReminderList(title: "Reminders"),
                                           dueDateComponents: existing)
                    let changes = try! parseReminderChanges(opts, existingItem: item)
                    if case .replaced(_, let comps) = changes.due {
                        expect(comps.year) == 2026
                        expect(comps.month) == 4
                        expect(comps.day) == 20
                        expect(comps.hour) == 15
                    } else {
                        fail("expected .replaced with merged components")
                    }
                }
                it("description includes time when merged") {
                    var opts = ParsedOptions(); opts.date = "3pm"
                    var existing = DateComponents()
                    existing.year = 2026; existing.month = 4; existing.day = 20
                    let item = ReminderItem(title: "Test", list: ReminderList(title: "Reminders"),
                                           dueDateComponents: existing)
                    let changes = try! parseReminderChanges(opts, existingItem: item)
                    expect(changes.descriptions.first).to(beginWith("due →"))
                }
            }

            context("recurrence") {
                it("clears recurrence when value is 'none'") {
                    var opts = ParsedOptions(); opts.recurrence = "none"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    if case .cleared = changes.recurrence { } else { fail("expected .cleared") }
                }
                it("adds 'repeat cleared' to descriptions") {
                    var opts = ParsedOptions(); opts.recurrence = "none"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.descriptions).to(contain("repeat cleared"))
                }
                it("adds recurrence when no existing recurrence") {
                    var opts = ParsedOptions(); opts.recurrence = "weekly"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    if case .added(let spec) = changes.recurrence {
                        expect(spec.frequency) == .weekly
                    } else {
                        fail("expected .added")
                    }
                }
                it("replaces recurrence when existing recurrence is present") {
                    var opts = ParsedOptions(); opts.recurrence = "weekly"
                    let existing = RecurrenceSpec(frequency: .daily, interval: 1)
                    let item = ReminderItem(title: "Test", list: ReminderList(title: "Reminders"),
                                           recurrenceSpec: existing)
                    let changes = try! parseReminderChanges(opts, existingItem: item)
                    if case .replaced(let from, let to) = changes.recurrence {
                        expect(from.frequency) == .daily
                        expect(to.frequency) == .weekly
                    } else {
                        fail("expected .replaced")
                    }
                }
                it("throws unrecognizedRecurrence for invalid input") {
                    var opts = ParsedOptions(); opts.recurrence = "garbage"
                    expect { try parseReminderChanges(opts, existingItem: noItem) }
                        .to(throwError(ReminderChangeError.unrecognizedRecurrence("garbage")))
                }
                it("leaves recurrence unchanged when empty") {
                    var opts = ParsedOptions(); opts.priority = "high"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    if case .unchanged = changes.recurrence { } else { fail("expected .unchanged") }
                }
            }

            context("priority") {
                it("replaces priority from 0 to 1 for 'high'") {
                    var opts = ParsedOptions(); opts.priority = "high"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.priority) == .replaced(from: 0, to: 1)
                }
                it("replaces priority to 0 for 'none'") {
                    var opts = ParsedOptions(); opts.priority = "none"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.priority) == .replaced(from: 0, to: 0)
                }
                it("carries existing priority as from value") {
                    var opts = ParsedOptions(); opts.priority = "low"
                    let item = ReminderItem(title: "Test", list: ReminderList(title: "Reminders"),
                                           priority: 1)
                    let changes = try! parseReminderChanges(opts, existingItem: item)
                    expect(changes.priority) == .replaced(from: 1, to: 9)
                }
                it("adds 'priority → high' to descriptions") {
                    var opts = ParsedOptions(); opts.priority = "high"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.descriptions).to(contain("priority → high"))
                }
                it("adds 'priority cleared' when priority is none") {
                    var opts = ParsedOptions(); opts.priority = "none"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.descriptions).to(contain("priority cleared"))
                }
                it("leaves priority unchanged when empty") {
                    var opts = ParsedOptions(); opts.note = "buy milk"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.priority) == .unchanged
                }
            }

            context("note") {
                it("clears note when value is 'none'") {
                    var opts = ParsedOptions(); opts.note = "none"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.note) == .cleared
                }
                it("adds note when no existing note") {
                    var opts = ParsedOptions(); opts.note = "buy milk"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.note) == .added("buy milk")
                }
                it("replaces note when existing note is present") {
                    var opts = ParsedOptions(); opts.note = "buy milk"
                    let item = ReminderItem(title: "Test", list: ReminderList(title: "Reminders"),
                                           notes: "old note")
                    let changes = try! parseReminderChanges(opts, existingItem: item)
                    expect(changes.note) == .replaced(from: "old note", to: "buy milk")
                }
                it("adds 'note cleared' to descriptions") {
                    var opts = ParsedOptions(); opts.note = "none"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.descriptions).to(contain("note cleared"))
                }
                it("adds '+ note' to descriptions for non-empty value") {
                    var opts = ParsedOptions(); opts.note = "buy milk"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.descriptions).to(contain("+ note"))
                }
            }

            context("url") {
                it("clears url when value is 'none'") {
                    var opts = ParsedOptions(); opts.url = "none"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.url) == .cleared
                }
                it("adds url when no existing url") {
                    var opts = ParsedOptions(); opts.url = "https://example.com"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.url) == .added(URL(string: "https://example.com")!)
                }
                it("replaces url when existing url is present") {
                    var opts = ParsedOptions(); opts.url = "https://example.com"
                    let item = ReminderItem(title: "Test", list: ReminderList(title: "Reminders"),
                                           url: URL(string: "https://old.com")!)
                    let changes = try! parseReminderChanges(opts, existingItem: item)
                    expect(changes.url) == .replaced(from: URL(string: "https://old.com")!,
                                                     to: URL(string: "https://example.com")!)
                }
                it("adds 'url cleared' to descriptions") {
                    var opts = ParsedOptions(); opts.url = "none"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.descriptions).to(contain("url cleared"))
                }
                it("adds 'url → ...' to descriptions for non-empty value") {
                    var opts = ParsedOptions(); opts.url = "https://example.com"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.descriptions).to(contain("url → https://example.com"))
                }
            }

            context("list") {
                it("replaces list field with current list as from value") {
                    var opts = ParsedOptions(); opts.list = "Work"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.list) == .replaced(from: "Reminders", to: "Work")
                }
                it("does not throw nothingToChange when only list is specified") {
                    var opts = ParsedOptions(); opts.list = "Work"
                    expect { try parseReminderChanges(opts, existingItem: noItem) }.notTo(throwError())
                }
                it("does not add list to descriptions (caller handles it)") {
                    var opts = ParsedOptions(); opts.list = "Work"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.descriptions).to(beEmpty())
                }
            }

            context("multiple fields") {
                it("collects descriptions for all changed fields") {
                    var opts = ParsedOptions()
                    opts.priority = "high"
                    opts.note = "buy milk"
                    let changes = try! parseReminderChanges(opts, existingItem: noItem)
                    expect(changes.descriptions.count) == 2
                }
            }
        }
    }
}
