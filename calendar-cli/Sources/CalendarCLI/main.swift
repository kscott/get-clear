// main.swift
//
// Entry point for the calendar-bin executable.
// Argument parsing and dispatch only — all logic lives in CalendarLib or CalendarCLI helpers.

import Foundation
import AppKit
import EventKit
import CalendarLib
import GetClearKit

let versionString = "\(builtVersion) (Get Clear \(suiteVersion))"

let store     = EKEventStore()
let semaphore = DispatchSemaphore(value: 0)
var args      = Array(CommandLine.arguments.dropFirst())

func usage() -> Never {
    print("""
    calendar \(versionString) — CLI for Apple Calendar

    Usage:
      calendar open                               # Open the Calendar app
      calendar calendars                          # List all available calendars
      calendar setup                              # Set up calendar groups
      calendar list <range>                       # Events in range
      calendar today                              # Today's events
      calendar week                               # This week's events
      calendar next [n]                           # Next N events (default 5)
      calendar find <query> [range]
      calendar show <title> [date]                # Full event detail
      calendar add <title> [date] [time to time]
      calendar remove <title> [date]

    Prefix a subset name to filter by calendar group:
      calendar work today
      calendar personal week

    Range: today, tomorrow, week, month, monday, "march 15", "march 15 to march 20", 7d
    Config: ~/.config/calendar-cli/config.toml
    Feedback: https://github.com/kscott/get-clear/issues
    """)
    exit(0)
}

// MARK: - Setup

let config = loadConfig()

let knownCommands: Set<String> = [
    "open", "calendars", "setup", "list", "today", "week", "next",
    "find", "show", "add", "remove"
]

var calFilter: String? = nil
if let first = args.first,
   !knownCommands.contains(first.lowercased()),
   !isHelpFlag(first), !isVersionFlag(first),
   config.subsets[first.lowercased()] != nil {
    calFilter = args.removeFirst()
}

// MARK: - Dispatch

let dispatch = parseArgs(args)
if case .version = dispatch { print(versionString); exit(0) }
guard case .command(let cmd, let args) = dispatch else { usage() }

store.requestFullAccessToEvents { granted, _ in
    guard granted else { fail("Calendar access denied") }

    func calendars() -> [EKCalendar] { resolveCalendars(calFilter, store: store, config: config) }
    func events(in range: ParsedRange) -> [EKEvent] { fetchEvents(in: range, calendars: calendars(), store: store) }
    func display(_ evts: [EKEvent]) -> [EventDisplayData] { evts.map(displayData) }

    switch cmd {

    case "what":
        let rangeStr = args.count > 1 ? Array(args.dropFirst()).joined(separator: " ") : "today"
        guard let range = parseRange(rangeStr) else { fail("Unrecognised range: \(rangeStr)") }
        let isToday = rangeStr == "today"
        let entries: [ActivityLogEntry]
        var dateUsed = Date()
        if isToday {
            let result = ActivityLogReader.entriesForDisplay(in: range.start...range.end)
            entries = result.entries; dateUsed = result.dateUsed
        } else {
            entries = ActivityLogReader.entries(in: range.start...range.end, tool: "calendar")
        }
        print(ActivityLogFormatter.perToolWhat(entries: entries, range: range, rangeStr: rangeStr,
                                               tool: "calendar", dateUsed: dateUsed))
        semaphore.signal()

    case "open":
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
        semaphore.signal()

    case "calendars":
        let all = store.calendars(for: .event)
        let grouped = Dictionary(grouping: all) { $0.source.title }
        for source in grouped.keys.sorted() {
            print(source)
            for cal in (grouped[source] ?? []).sorted(by: { $0.title < $1.title }) {
                print("  \(colorDot(calendarColor(cal)))\(cal.title)")
            }
        }
        semaphore.signal()

    case "setup":
        runSetup(store: store)
        semaphore.signal()

    case "list":
        guard args.count > 1 else { fail("provide a range (e.g. today, week, 7d, \"march 15 to march 20\")") }
        let rangeStr = args.dropFirst().joined(separator: " ")
        guard let range = parseRange(rangeStr) else { fail("unrecognised range: \(rangeStr)") }
        let evts = display(events(in: range))
        if evts.isEmpty { print("No events — \(formatRangeDescription(range))") }
        else if range.isSingleDay { printFlat(evts, showHeader: true, header: dayHeaderFormatter.string(from: range.start), calFilter: calFilter) }
        else { printGrouped(evts, calFilter: calFilter) }
        semaphore.signal()

    case "today":
        let range = parseRange("today")!
        let evts  = display(events(in: range))
        let hdr   = dayHeaderFormatter.string(from: range.start)
        if evts.isEmpty { print("\(hdr)\n  (nothing scheduled)") }
        else { printFlat(evts, showHeader: true, header: hdr, calFilter: calFilter) }
        semaphore.signal()

    case "week":
        let evts = display(events(in: parseRange("week")!))
        if evts.isEmpty { print("No events this week") }
        else { printGrouped(evts, calFilter: calFilter) }
        semaphore.signal()

    case "next":
        let n   = args.count > 1 ? (Int(args[1]) ?? 5) : 5
        let now = Date()
        let upcoming = events(in: parseRange("90d")!).filter { $0.endDate > now }.prefix(n)
        if upcoming.isEmpty { print("No upcoming events in the next 90 days") }
        else {
            for e in upcoming {
                let lbl  = nextRelativeLabel(for: e.startDate, relativeTo: now)
                let time = e.isAllDay ? "All day  " : formatEventTime(e.startDate)
                var txt  = e.title ?? "(no title)"
                if let loc = e.location, !loc.isEmpty { txt += " · " + (loc.components(separatedBy: "\n").first ?? loc) }
                print("\(colorDot(calendarColor(e.calendar))) \(lbl)  \(time)   \(txt)")
            }
        }
        semaphore.signal()

    case "find":
        guard args.count > 1 else { fail("provide a search query") }
        let rem = Array(args.dropFirst())
        var query: String; var range: ParsedRange
        if rem.count > 1, let r = parseRange(rem.dropFirst().joined(separator: " ")) { query = rem[0]; range = r }
        else if rem.count > 1, let r = parseRange(rem.last!) { query = rem.dropLast().joined(separator: " "); range = r }
        else { query = rem.joined(separator: " "); range = parseRange("30d")! }
        let lower   = query.lowercased()
        let matches = display(events(in: range).filter {
            ($0.title?.lowercased().contains(lower) ?? false) || ($0.notes?.lowercased().contains(lower) ?? false)
        })
        if matches.isEmpty { print("No events matching '\(query)' in \(formatRangeDescription(range))") }
        else { printGrouped(matches, calFilter: calFilter) }
        semaphore.signal()

    case "show":
        guard args.count > 1 else { fail("provide an event title") }
        let title   = args[1]
        let rangeStr = args.count > 2 ? args.dropFirst(2).joined(separator: " ") : nil
        let range   = rangeStr.flatMap { parseRange($0) } ?? parseRange("30d")!
        let lower   = title.lowercased()
        let all     = store.calendars(for: .event)
        let matches = fetchEvents(in: range, calendars: all, store: store).filter {
            ($0.title ?? "").caseInsensitiveCompare(title) == .orderedSame ||
            ($0.title ?? "").lowercased().contains(lower)
        }
        guard !matches.isEmpty else { fail("Not found: \(title)") }
        if matches.count > 1 {
            let df = DateFormatter(); df.dateFormat = "EEE MMM d"
            print("Multiple events match '\(title)':")
            for e in matches { print("  \(df.string(from: e.startDate))  \(e.isAllDay ? "all day" : formatEventTime(e.startDate))  \(e.title ?? "")") }
            print("Add a date to narrow the search, e.g.: calendar show \"\(title)\" tomorrow")
            exit(1)
        }
        let e = matches[0]; let cal = Calendar.current
        print(e.title ?? "(no title)")
        if e.isAllDay {
            let f = DateFormatter(); f.dateFormat = "EEE MMM d, yyyy"
            print("  Date:       \(f.string(from: e.startDate)) (all day)")
        } else {
            let df = DateFormatter(); df.dateFormat = "EEE MMM d, yyyy"
            let end = cal.isDate(e.startDate, inSameDayAs: e.endDate)
                      ? formatEventTime(e.endDate) : df.string(from: e.endDate) + " " + formatEventTime(e.endDate)
            print("  Date:       \(df.string(from: e.startDate)), \(formatEventTime(e.startDate)) – \(end)")
        }
        print("  Calendar:   \(e.calendar.title)")
        if let loc = e.location, !loc.isEmpty { print("  Location:   \(loc)") }
        if let url = e.url { print("  URL:        \(url.absoluteString)") }
        if let attendees = e.attendees, !attendees.isEmpty {
            let names = attendees.compactMap { p -> String? in
                guard let name = p.name else { return nil }
                let s: String
                switch p.participantStatus {
                case .accepted: s = "accepted"; case .declined: s = "declined"
                case .tentative: s = "tentative"; default: s = "invited"
                }
                return "\(name) (\(s))"
            }
            if !names.isEmpty { print("  Attendees:  \(names.joined(separator: ", "))") }
        }
        if let notes = e.notes, !notes.isEmpty {
            let lines = notes.components(separatedBy: "\n")
            print("  Notes:      \(lines[0])")
            for line in lines.dropFirst() where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                print("              \(line)")
            }
        }
        semaphore.signal()

    case "add":
        guard args.count > 1 else { fail("provide an event title") }
        let title  = args[1]
        let dStr   = Array(args.dropFirst(2)).joined(separator: " ")
        guard let edt = parseEventDateTime(dStr.isEmpty ? "today" : dStr) else { fail("unrecognised date/time: \(dStr)") }
        guard let targetCal = calendars().first ?? store.defaultCalendarForNewEvents else { fail("no calendar available") }
        let endDate = edt.end ?? Calendar.current.date(byAdding: .hour, value: 1, to: edt.start)!
        let ev = EKEvent(eventStore: store)
        ev.title = title; ev.calendar = targetCal; ev.isAllDay = edt.isAllDay
        ev.startDate = edt.start; ev.endDate = endDate
        do {
            try store.save(ev, span: .thisEvent, commit: true)
            try? ActivityLog.write(tool: "calendar", cmd: "add", desc: title, container: targetCal.title)
            let df = DateFormatter(); df.dateFormat = "EEE MMM d"
            let detail = edt.isAllDay ? "all day" : "\(formatEventTime(edt.start)) – \(formatEventTime(endDate))"
            print("Added: \(title) · \(df.string(from: edt.start)) \(detail) (\(targetCal.title))")
        } catch { fail("Could not save event: \(error.localizedDescription)") }
        semaphore.signal()

    case "remove":
        guard args.count > 1 else { fail("provide an event title") }
        let title   = args[1]
        let rangeStr = args.count > 2 ? Array(args.dropFirst(2)).joined(separator: " ") : nil
        let range   = rangeStr.flatMap { parseRange($0) } ?? parseRange("30d")!
        let lower   = title.lowercased()
        let matches = events(in: range).filter {
            ($0.title ?? "").caseInsensitiveCompare(title) == .orderedSame ||
            ($0.title ?? "").lowercased().contains(lower)
        }
        guard !matches.isEmpty else { fail("Not found: \(title)") }
        if matches.count > 1 {
            let df = DateFormatter(); df.dateFormat = "EEE MMM d"
            print("Multiple events match '\(title)':")
            for e in matches { print("  \(df.string(from: e.startDate))  \(e.isAllDay ? "all day" : formatEventTime(e.startDate))  \(e.title ?? "")") }
            print("Add a date to narrow the search, e.g.: calendar remove \"\(title)\" tomorrow"); exit(1)
        }
        let ev = matches[0]
        do {
            let calName = ev.calendar.title; let evTitle = ev.title ?? ""
            try store.remove(ev, span: .thisEvent, commit: true)
            try? ActivityLog.write(tool: "calendar", cmd: "remove", desc: evTitle, container: calName)
            let df = DateFormatter(); df.dateFormat = "EEE MMM d"
            print("Removed: \(evTitle) (\(df.string(from: ev.startDate)))")
        } catch { fail("Could not remove event: \(error.localizedDescription)") }
        semaphore.signal()

    default:
        let rangeStr = args.joined(separator: " ")
        if let range = parseRange(rangeStr) {
            let evts = display(events(in: range))
            if evts.isEmpty { print("No events — \(formatRangeDescription(range))") }
            else if range.isSingleDay { printFlat(evts, showHeader: true, header: dayHeaderFormatter.string(from: range.start), calFilter: calFilter) }
            else { printGrouped(evts, calFilter: calFilter) }
        } else { usage() }
        semaphore.signal()
    }
}

semaphore.wait()
UpdateChecker.spawnBackgroundCheckIfNeeded()
if let hint = UpdateChecker.hint() { fputs(hint + "\n", stderr) }
