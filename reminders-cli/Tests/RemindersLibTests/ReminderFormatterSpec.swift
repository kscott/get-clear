// ReminderFormatterSpec.swift
//
// Tests for ReminderFormatter — metaLine, row formatters, show output, and lookup messages.

import Foundation
import GetClearKit
import Nimble
import Quick
import RemindersLib

final class ReminderFormatterSpec: QuickSpec {
    override class func spec() {
        describe("metaLine") {
            context("no metadata") {
                it("returns empty string for empty meta") {
                    expect(metaLine(for: ReminderMeta())) == ""
                }
                it("returns empty string when all flags are false and priority is 0") {
                    expect(
                        metaLine(for: ReminderMeta(formattedDue: nil, isRepeating: false, priority: 0, hasNote: false, hasURL: false))
                    ) ==
                        ""
                }
            }

            context("due date") {
                it("includes formattedDue string when present") {
                    let meta = ReminderMeta(formattedDue: "Fri Apr 11 · 3:00pm")
                    expect(metaLine(for: meta)).to(contain("Fri Apr 11 · 3:00pm"))
                }
                it("returns empty string when formattedDue is nil") {
                    expect(metaLine(for: ReminderMeta(formattedDue: nil))) == ""
                }
            }

            context("repeating") {
                it("includes 'repeating' when isRepeating is true") {
                    expect(metaLine(for: ReminderMeta(isRepeating: true))).to(contain("repeating"))
                }
                it("does not include 'repeating' when isRepeating is false") {
                    expect(metaLine(for: ReminderMeta(isRepeating: false))) == ""
                }
            }

            context("priority") {
                it("shows 'high' for priority 1") {
                    expect(metaLine(for: ReminderMeta(priority: 1))).to(contain("high"))
                }
                it("shows 'high' for priority 4") {
                    expect(metaLine(for: ReminderMeta(priority: 4))).to(contain("high"))
                }
                it("shows 'medium' for priority 5") {
                    expect(metaLine(for: ReminderMeta(priority: 5))).to(contain("medium"))
                }
                it("shows 'low' for priority 6") {
                    expect(metaLine(for: ReminderMeta(priority: 6))).to(contain("low"))
                }
                it("shows 'low' for priority 9") {
                    expect(metaLine(for: ReminderMeta(priority: 9))).to(contain("low"))
                }
                it("shows nothing for priority 0") {
                    expect(metaLine(for: ReminderMeta(priority: 0))) == ""
                }
                it("shows nothing for priority 10 (out of range)") {
                    expect(metaLine(for: ReminderMeta(priority: 10))) == ""
                }
            }

            context("note and url") {
                it("includes '+ note' when hasNote is true") {
                    expect(metaLine(for: ReminderMeta(hasNote: true))).to(contain("+ note"))
                }
                it("includes '+ url' when hasURL is true") {
                    expect(metaLine(for: ReminderMeta(hasURL: true))).to(contain("+ url"))
                }
                it("does not include '+ note' when hasNote is false") {
                    expect(metaLine(for: ReminderMeta(hasNote: false))) == ""
                }
                it("does not include '+ url' when hasURL is false") {
                    expect(metaLine(for: ReminderMeta(hasURL: false))) == ""
                }
            }

            context("format") {
                it("starts with '  ·  ' when any field is present") {
                    expect(metaLine(for: ReminderMeta(isRepeating: true))).to(beginWith("  ·  "))
                }
                it("joins multiple fields with ' · '") {
                    let meta = ReminderMeta(isRepeating: true, priority: 1)
                    expect(metaLine(for: meta)) == "  ·  repeating · high"
                }
                it("due appears before repeating") {
                    let meta = ReminderMeta(formattedDue: "Mon Apr 14", isRepeating: true)
                    expect(metaLine(for: meta)) == "  ·  Mon Apr 14 · repeating"
                }
                it("all fields produce correct full string") {
                    let meta = ReminderMeta(
                        formattedDue: "Mon Apr 14",
                        isRepeating: true,
                        priority: 1,
                        hasNote: true,
                        hasURL: true
                    )
                    expect(metaLine(for: meta)) == "  ·  Mon Apr 14 · repeating · high · + note · + url"
                }
            }
        }

        describe("notFoundMessage") {
            it("includes the title") {
                expect(notFoundMessage(title: "Pay rent", list: nil)).to(contain("Pay rent"))
            }
            it("does not mention a list when list is nil") {
                expect(notFoundMessage(title: "Pay rent", list: nil)) == "Not found: Pay rent"
            }
            it("includes the list name when provided") {
                expect(notFoundMessage(title: "Pay rent", list: "Personal")) == "Not found: Pay rent in Personal"
            }
        }

        describe("disambiguationMessage") {
            it("opens with the title") {
                let matches = [makeItem(), makeItem(list: workList)]
                expect(disambiguationMessage(title: "Pay rent", matches: matches, cmd: "done"))
                    .to(beginWith("Multiple reminders named 'Pay rent':"))
            }
            it("lists each matching list title") {
                let matches = [makeItem(), makeItem(list: workList)]
                let msg = disambiguationMessage(title: "Pay rent", matches: matches, cmd: "done")
                expect(msg).to(contain("[Personal]"))
                expect(msg).to(contain("[Work]"))
            }
            it("ends with a narrowing hint including the command name") {
                let matches = [makeItem(), makeItem(list: workList)]
                let msg = disambiguationMessage(title: "Pay rent", matches: matches, cmd: "done")
                expect(msg).to(contain("reminders done"))
                expect(msg).to(contain("Personal"))
            }
        }

        describe("formatAddConfirmation") {
            context("title only") {
                it("includes 'Added:' prefix with title and list") {
                    let result = formatAddConfirmation(
                        title: "Pay rent", list: "Personal",
                        date: nil, recurrence: nil,
                        priority: "", hasNote: false, url: ""
                    )
                    expect(result) == "Added: Pay rent (in Personal)"
                }
            }
            context("with due date") {
                it("appends due date segment") {
                    let pd = ParsedDate(date: Date(timeIntervalSince1970: 0), hasTime: false, hasDate: true)
                    let result = formatAddConfirmation(
                        title: "Pay rent", list: "Personal",
                        date: pd, recurrence: nil,
                        priority: "", hasNote: false, url: ""
                    )
                    expect(result).to(contain("due"))
                }
            }
            context("with recurrence") {
                it("appends recurrence description") {
                    let spec = RecurrenceSpec(frequency: .monthly, interval: 1)
                    let result = formatAddConfirmation(
                        title: "Pay rent", list: "Personal",
                        date: nil, recurrence: spec,
                        priority: "", hasNote: false, url: ""
                    )
                    expect(result).to(contain("repeat monthly"))
                }
            }
            context("with priority") {
                it("appends priority label") {
                    let result = formatAddConfirmation(
                        title: "Pay rent", list: "Personal",
                        date: nil, recurrence: nil,
                        priority: "high", hasNote: false, url: ""
                    )
                    expect(result).to(contain("priority high"))
                }
                it("omits priority segment when priority is empty") {
                    let result = formatAddConfirmation(
                        title: "Pay rent", list: "Personal",
                        date: nil, recurrence: nil,
                        priority: "", hasNote: false, url: ""
                    )
                    expect(result).notTo(contain("priority"))
                }
            }
            context("with note") {
                it("appends '+ note' when hasNote is true") {
                    let result = formatAddConfirmation(
                        title: "Pay rent", list: "Personal",
                        date: nil, recurrence: nil,
                        priority: "", hasNote: true, url: ""
                    )
                    expect(result).to(contain("+ note"))
                }
                it("omits note segment when hasNote is false") {
                    let result = formatAddConfirmation(
                        title: "Pay rent", list: "Personal",
                        date: nil, recurrence: nil,
                        priority: "", hasNote: false, url: ""
                    )
                    expect(result).notTo(contain("note"))
                }
            }
            context("with url") {
                it("appends url value") {
                    let result = formatAddConfirmation(
                        title: "Pay rent", list: "Personal",
                        date: nil, recurrence: nil,
                        priority: "", hasNote: false, url: "https://example.com"
                    )
                    expect(result).to(contain("url https://example.com"))
                }
                it("omits url segment when url is empty") {
                    let result = formatAddConfirmation(
                        title: "Pay rent", list: "Personal",
                        date: nil, recurrence: nil,
                        priority: "", hasNote: false, url: ""
                    )
                    expect(result).notTo(contain("url"))
                }
            }
            context("all fields populated") {
                it("joins all segments with ' · '") {
                    let spec = RecurrenceSpec(frequency: .weekly, interval: 1)
                    let result = formatAddConfirmation(
                        title: "Pay rent", list: "Personal",
                        date: nil, recurrence: spec,
                        priority: "high", hasNote: true, url: "https://example.com"
                    )
                    expect(result).to(contain(" · "))
                    expect(result).to(contain("repeat weekly"))
                    expect(result).to(contain("priority high"))
                    expect(result).to(contain("+ note"))
                    expect(result).to(contain("url https://example.com"))
                }
            }
        }

        describe("formatFindRow") {
            it("includes the bold title") {
                expect(formatFindRow(makeItem())).to(contain("Pay rent"))
            }
            it("includes the list title in brackets") {
                expect(formatFindRow(makeItem())).to(contain("[Personal]"))
            }
            it("does not include a due prefix when no due date is set") {
                expect(formatFindRow(makeItem())).notTo(contain("due"))
            }
            it("includes a due prefix when a due date is set") {
                let comps = DateComponents(calendar: .current, year: 2026, month: 6, day: 15)
                expect(formatFindRow(makeItem(dueDateComponents: comps))).to(contain("due"))
            }
        }

        describe("formatListRow") {
            it("includes a due date in the meta when a due date is set") {
                let comps = DateComponents(calendar: .current, year: 2026, month: 6, day: 15)
                expect(formatListRow(makeItem(dueDateComponents: comps))).to(contain("Jun"))
            }
        }

        describe("formatShow") {
            it("includes the title") {
                expect(formatShow(item: makeItem())).to(contain("Pay rent"))
            }
            it("includes the list name") {
                expect(formatShow(item: makeItem())).to(contain("Personal"))
            }
            it("does not include a Due line when no due date is set") {
                expect(formatShow(item: makeItem())).notTo(contain("Due:"))
            }
            it("includes the Due line when a due date is set") {
                let comps = DateComponents(calendar: .current, year: 2026, month: 6, day: 15)
                expect(formatShow(item: makeItem(dueDateComponents: comps))).to(contain("Due:"))
            }
            it("includes the Repeat line when recurrenceDescription is set") {
                expect(formatShow(item: makeItem(recurrenceDescription: "monthly"))).to(contain("Repeat:   monthly"))
            }
            it("does not include a Repeat line when recurrenceDescription is nil") {
                expect(formatShow(item: makeItem())).notTo(contain("Repeat:"))
            }
            it("includes the Priority line for high priority") {
                expect(formatShow(item: makeItem(priority: 1))).to(contain("Priority: high"))
            }
            it("includes the Note line when notes is non-empty") {
                expect(formatShow(item: makeItem(notes: "First of month"))).to(contain("Note:     First of month"))
            }
            it("does not include a Note line when notes is nil") {
                expect(formatShow(item: makeItem())).notTo(contain("Note:"))
            }
            it("includes the URL line when url is set") {
                expect(formatShow(item: makeItem(url: URL(string: "https://example.com")!))).to(contain("URL:      https://example.com"))
            }
        }
    }
}
