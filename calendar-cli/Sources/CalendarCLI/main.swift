// main.swift
//
// Entry point for the calendar-bin executable.
// Argument parsing, dispatch, and EventKit/AppKit interactions only.
// Formatting, parsing, and calendar resolution are delegated to CalendarLib.

import Foundation
import AppKit
import EventKit
import CalendarLib
import GetClearKit

let version = builtVersion
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
      calendar work next 5

    Range examples:
      today, tomorrow, yesterday
      week, last week, next week
      month, last month, next month
      monday, friday                              (next occurrence, or today if today)
      "march 15", "2026-03-15"                   (specific date)
      "march 15 to march 20"                     (explicit range)
      "next monday to friday"                    (relative range)
      7d, 30d                                    (N days from today)

    Config: ~/.config/calendar-cli/config.toml
      [subsets]
      work     = ["Work", "Meetings"]
      personal = ["Home", "Family"]

    Feedback: https://github.com/kscott/get-clear/issues
    """)
    exit(0)
}

// MARK: - Helpers

let config = loadConfig()

/// Extracts an RGB color triple from an EKCalendar's CGColor, or nil when unavailable.
/// Kept in CalendarCLI because it requires AppKit (CGColor, colorSpace).
func calendarColor(_ cal: EKCalendar) -> (r: Int, g: Int, b: Int)? {
    guard let cg = cal.cgColor else { return nil }
    let colorSpace = cg.colorSpace?.model
    let components = cg.components ?? []
    if colorSpace == .rgb, components.count >= 3 {
        return (Int(components[0] * 255), Int(components[1] * 255), Int(components[2] * 255))
    } else if colorSpace == .monochrome, components.count >= 1 {
        let w = Int(components[0] * 255)
        return (w, w, w)
    }
    return nil
}

/// Converts an EKEvent to the plain-data EventDisplayData required by CalendarLib formatters.
func displayData(for event: EKEvent) -> EventDisplayData {
    EventDisplayData(
        title:         event.title ?? "(no title)",
        start:         event.startDate,
        end:           event.endDate,
        isAllDay:      event.isAllDay,
        calendarName:  event.calendar.title,
        calendarColor: calendarColor(event.calendar),
        location:      event.location
    )
}

// MARK: - Calendar filter extraction (positional prefix)

let knownCommands: Set<String> = [
    "open", "calendars", "setup", "list", "today", "week", "next",
    "find", "show", "add", "remove"
]

/// If the first arg is a known config subset, extract it as the calendar filter.
/// `calendar work today` → calFilter = "work", args becomes ["today", ...]
var calFilter: String? = nil
if let first = args.first,
   !knownCommands.contains(first.lowercased()),
   !isHelpFlag(first), !isVersionFlag(first),
   config.subsets[first.lowercased()] != nil {
    calFilter = args.removeFirst()
}

func resolveCalendars(_ filter: String?) -> [EKCalendar] {
    let all = store.calendars(for: .event)
    guard let filter else { return all }
    let tokens = filter.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    var seen = Set<String>()
    var result: [EKCalendar] = []
    for token in tokens {
        if let names = config.subsets[token.lowercased()] {
            let matched = all.filter { names.contains($0.title) && !seen.contains($0.calendarIdentifier) }
            if matched.isEmpty { fail("No calendars matched subset '\(token)'") }
            matched.forEach { seen.insert($0.calendarIdentifier); result.append($0) }
        } else {
            let matched = all.filter { $0.title == token && !seen.contains($0.calendarIdentifier) }
            if matched.isEmpty { fail("Calendar not found: \(token)") }
            matched.forEach { seen.insert($0.calendarIdentifier); result.append($0) }
        }
    }
    return result
}

func fetchEvents(in range: ParsedRange, calendars: [EKCalendar]) -> [EKEvent] {
    let predicate = store.predicateForEvents(withStart: range.start,
                                             end: range.end,
                                             calendars: calendars.isEmpty ? nil : calendars)
    let sorted = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    // Deduplicate recurring-event instances that appear twice (e.g. spanning midnight)
    var seen = Set<String>()
    return sorted.filter { seen.insert($0.eventIdentifier).inserted }
}

// MARK: - Dispatch

let dispatch = parseArgs(args)
if case .version = dispatch { print(versionString); exit(0) }
guard case .command(let cmd, let args) = dispatch else { usage() }

store.requestFullAccessToEvents { granted, _ in
    guard granted else { fail("Calendar access denied") }

    switch cmd {

    case "what":
        let rangeStr = args.count > 1 ? Array(args.dropFirst()).joined(separator: " ") : "today"
        guard let range = parseRange(rangeStr) else { fail("Unrecognised range: \(rangeStr)") }
        let isToday = rangeStr == "today"
        let entries: [ActivityLogEntry]
        var dateUsed = Date()
        if isToday {
            let result = ActivityLogReader.entriesForDisplay(in: range.start...range.end)
            entries  = result.entries
            dateUsed = result.dateUsed
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
        let all = store.calendars(for: .event)

        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/calendar-cli")
        let configURL = configDir.appendingPathComponent("config.toml")

        if FileManager.default.fileExists(atPath: configURL.path) {
            print("Existing config found — running setup will overwrite it.\n")
        }

        var numberedCals: [(Int, EKCalendar)] = []
        var n = 1
        let grouped = Dictionary(grouping: all) { $0.source.title }
        print("Available calendars:\n")
        for source in grouped.keys.sorted() {
            print("  \(source)")
            for cal in (grouped[source] ?? []).sorted(by: { $0.title < $1.title }) {
                print(String(format: "    %2d  \(colorDot(calendarColor(cal)))\(cal.title)", n))
                numberedCals.append((n, cal))
                n += 1
            }
        }

        print("\nCreate subsets to group calendars (e.g. \"work\", \"personal\").")
        print("Enter calendar names or numbers, comma-separated. Press Enter with no name to finish.\n")

        var subsets: [(String, [String])] = []

        signal(SIGINT) { _ in print("\nCancelled."); exit(0) }

        while true {
            print("Subset name: ", terminator: "")
            fflush(stdout)
            guard let rawNameInput = readLine() else { print("\nCancelled."); break }
            let nameInput = String(rawNameInput.unicodeScalars.filter { $0.value >= 32 && $0.value < 127 })
            let subsetName = nameInput.trimmingCharacters(in: .whitespaces).lowercased()
            guard !subsetName.isEmpty else { break }

            print("Calendars for \"\(subsetName)\": ", terminator: "")
            fflush(stdout)
            guard let rawCalInput = readLine() else { print("\nCancelled."); break }
            let calInput = String(rawCalInput.unicodeScalars.filter { $0.value >= 32 && $0.value < 127 })
            guard !calInput.trimmingCharacters(in: .whitespaces).isEmpty else {
                print("  No calendars entered — skipping\n")
                continue
            }

            let tokens = calInput.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            var calNames: [String] = []
            var unmatched: [String] = []

            for token in tokens {
                if let num = Int(token),
                   let match = numberedCals.first(where: { $0.0 == num }) {
                    calNames.append(match.1.title)
                } else if let match = all.first(where: { $0.title.lowercased() == token.lowercased() }) {
                    calNames.append(match.title)
                } else {
                    unmatched.append(token)
                }
            }

            if !unmatched.isEmpty {
                print("  Not found: \(unmatched.joined(separator: ", ")) — skipping those")
            }
            guard !calNames.isEmpty else {
                print("  No valid calendars — skipping\n")
                continue
            }

            let quoted = calNames.map { "\"\($0)\"" }.joined(separator: ", ")
            print("  → \(subsetName) = [\(quoted)]\n")
            subsets.append((subsetName, calNames))
        }

        guard !subsets.isEmpty else {
            print("\nNo subsets defined — nothing written.")
            semaphore.signal()
            return
        }

        var toml = "[subsets]\n"
        for (name, cals) in subsets {
            let quoted = cals.map { "\"\($0)\"" }.joined(separator: ", ")
            toml += "\(name) = [\(quoted)]\n"
        }

        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            try toml.write(to: configURL, atomically: true, encoding: .utf8)
            print("Config written to \(configURL.path)")
            if let first = subsets.first {
                print("Try it: calendar \(first.0) today")
            }
        } catch {
            fail("Could not write config: \(error.localizedDescription)")
        }
        semaphore.signal()

    case "list":
        guard args.count > 1 else { fail("provide a range (e.g. today, week, 7d, \"march 15 to march 20\")") }
        let rangeStr = args.dropFirst().joined(separator: " ")
        guard let range = parseRange(rangeStr) else { fail("unrecognised range: \(rangeStr)") }
        let events = fetchEvents(in: range, calendars: resolveCalendars(calFilter)).map(displayData)
        if events.isEmpty {
            print("No events — \(formatRangeDescription(range))")
        } else if range.isSingleDay {
            printFlat(events, showHeader: true, header: dayHeaderFormatter.string(from: range.start),
                      calFilter: calFilter)
        } else {
            printGrouped(events, calFilter: calFilter)
        }
        semaphore.signal()

    case "today":
        let range  = parseRange("today")!
        let events = fetchEvents(in: range, calendars: resolveCalendars(calFilter)).map(displayData)
        let header = dayHeaderFormatter.string(from: range.start)
        if events.isEmpty {
            print("\(header)\n  (nothing scheduled)")
        } else {
            printFlat(events, showHeader: true, header: header, calFilter: calFilter)
        }
        semaphore.signal()

    case "week":
        let range  = parseRange("week")!
        let events = fetchEvents(in: range, calendars: resolveCalendars(calFilter)).map(displayData)
        if events.isEmpty {
            print("No events this week")
        } else {
            printGrouped(events, calFilter: calFilter)
        }
        semaphore.signal()

    case "next":
        let n = args.count > 1 ? (Int(args[1]) ?? 5) : 5
        let now      = Date()
        let upcoming = fetchEvents(in: parseRange("90d")!, calendars: resolveCalendars(calFilter))
            .filter { $0.endDate > now }
            .prefix(n)
        if upcoming.isEmpty {
            print("No upcoming events in the next 90 days")
        } else {
            for event in upcoming {
                let dateLabel = nextRelativeLabel(for: event.startDate, relativeTo: now)
                let timeStr   = event.isAllDay ? "All day  " : formatEventTime(event.startDate)
                var label     = event.title ?? "(no title)"
                if let loc = event.location, !loc.isEmpty {
                    label += " · " + (loc.components(separatedBy: "\n").first ?? loc)
                }
                print("\(colorDot(calendarColor(event.calendar))) \(dateLabel)  \(timeStr)   \(label)")
            }
        }
        semaphore.signal()

    case "find":
        guard args.count > 1 else { fail("provide a search query") }
        let remaining = Array(args.dropFirst())
        var query: String
        var range: ParsedRange
        if remaining.count > 1, let r = parseRange(remaining.dropFirst().joined(separator: " ")) {
            query = remaining[0]; range = r
        } else if remaining.count > 1, let r = parseRange(remaining.last!) {
            query = remaining.dropLast().joined(separator: " "); range = r
        } else {
            query = remaining.joined(separator: " "); range = parseRange("30d")!
        }
        let lower   = query.lowercased()
        let matches = fetchEvents(in: range, calendars: resolveCalendars(calFilter))
            .filter { ($0.title?.lowercased().contains(lower) ?? false) ||
                      ($0.notes?.lowercased().contains(lower) ?? false) }
            .map(displayData)
        if matches.isEmpty {
            print("No events matching '\(query)' in \(formatRangeDescription(range))")
        } else {
            printGrouped(matches, calFilter: calFilter)
        }
        semaphore.signal()

    case "show":
        guard args.count > 1 else { fail("provide an event title") }
        let title    = args[1]
        let rangeStr = args.count > 2 ? args.dropFirst(2).joined(separator: " ") : nil
        let range    = rangeStr.flatMap { parseRange($0) } ?? parseRange("30d")!
        let lower    = title.lowercased()
        let matches  = fetchEvents(in: range, calendars: store.calendars(for: .event))
            .filter { ($0.title ?? "").caseInsensitiveCompare(title) == .orderedSame ||
                      ($0.title ?? "").lowercased().contains(lower) }
        guard !matches.isEmpty else { fail("Not found: \(title)") }
        if matches.count > 1 {
            let df = DateFormatter(); df.dateFormat = "EEE MMM d"
            print("Multiple events match '\(title)':")
            for e in matches {
                let timeStr = e.isAllDay ? "all day" : formatEventTime(e.startDate)
                print("  \(df.string(from: e.startDate))  \(timeStr)  \(e.title ?? "")")
            }
            print("Add a date to narrow the search, e.g.: calendar show \"\(title)\" tomorrow")
            exit(1)
        }
        let event = matches[0]
        let cal   = Calendar.current
        print(event.title ?? "(no title)")
        if event.isAllDay {
            let f = DateFormatter(); f.dateFormat = "EEE MMM d, yyyy"
            print("  Date:       \(f.string(from: event.startDate)) (all day)")
        } else {
            let df      = DateFormatter(); df.dateFormat = "EEE MMM d, yyyy"
            let sameDay = cal.isDate(event.startDate, inSameDayAs: event.endDate)
            let endPart = sameDay ? formatEventTime(event.endDate)
                                  : df.string(from: event.endDate) + " " + formatEventTime(event.endDate)
            print("  Date:       \(df.string(from: event.startDate)), \(formatEventTime(event.startDate)) – \(endPart)")
        }
        print("  Calendar:   \(event.calendar.title)")
        if let loc = event.location, !loc.isEmpty { print("  Location:   \(loc)") }
        if let url = event.url { print("  URL:        \(url.absoluteString)") }
        if let attendees = event.attendees, !attendees.isEmpty {
            let names = attendees.compactMap { p -> String? in
                guard let name = p.name else { return nil }
                let status: String
                switch p.participantStatus {
                case .accepted:  status = "accepted"
                case .declined:  status = "declined"
                case .tentative: status = "tentative"
                default:         status = "invited"
                }
                return "\(name) (\(status))"
            }
            if !names.isEmpty { print("  Attendees:  \(names.joined(separator: ", "))") }
        }
        if let notes = event.notes, !notes.isEmpty {
            let lines = notes.components(separatedBy: "\n")
            print("  Notes:      \(lines[0])")
            for line in lines.dropFirst() where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                print("              \(line)")
            }
        }
        semaphore.signal()

    case "add":
        guard args.count > 1 else { fail("provide an event title") }
        let title   = args[1]
        let dateStr = Array(args.dropFirst(2)).joined(separator: " ")
        guard let edt = parseEventDateTime(dateStr.isEmpty ? "today" : dateStr) else {
            fail("unrecognised date/time: \(dateStr)")
        }
        guard let targetCal = resolveCalendars(calFilter).first ?? store.defaultCalendarForNewEvents else {
            fail("no calendar available")
        }
        let endDate  = edt.end ?? Calendar.current.date(byAdding: .hour, value: 1, to: edt.start)!
        let event    = EKEvent(eventStore: store)
        event.title     = title
        event.calendar  = targetCal
        event.isAllDay  = edt.isAllDay
        event.startDate = edt.start
        event.endDate   = endDate
        do {
            try store.save(event, span: .thisEvent, commit: true)
            try? ActivityLog.write(tool: "calendar", cmd: "add", desc: title, container: targetCal.title)
            let df         = DateFormatter(); df.dateFormat = "EEE MMM d"
            let timeDetail = edt.isAllDay ? "all day"
                                          : "\(formatEventTime(edt.start)) – \(formatEventTime(endDate))"
            print("Added: \(title) · \(df.string(from: edt.start)) \(timeDetail) (\(targetCal.title))")
        } catch {
            fail("Could not save event: \(error.localizedDescription)")
        }
        semaphore.signal()

    case "remove":
        guard args.count > 1 else { fail("provide an event title") }
        let title    = args[1]
        let rangeStr = args.count > 2 ? Array(args.dropFirst(2)).joined(separator: " ") : nil
        let range    = rangeStr.flatMap { parseRange($0) } ?? parseRange("30d")!
        let lower    = title.lowercased()
        let matches  = fetchEvents(in: range, calendars: resolveCalendars(calFilter))
            .filter { ($0.title ?? "").caseInsensitiveCompare(title) == .orderedSame ||
                      ($0.title ?? "").lowercased().contains(lower) }
        guard !matches.isEmpty else { fail("Not found: \(title)") }
        if matches.count > 1 {
            let df = DateFormatter(); df.dateFormat = "EEE MMM d"
            print("Multiple events match '\(title)':")
            for e in matches {
                let timeStr = e.isAllDay ? "all day" : formatEventTime(e.startDate)
                print("  \(df.string(from: e.startDate))  \(timeStr)  \(e.title ?? "")")
            }
            print("Add a date to narrow the search, e.g.: calendar remove \"\(title)\" tomorrow")
            exit(1)
        }
        let event = matches[0]
        do {
            let calName    = event.calendar.title
            let eventTitle = event.title ?? ""
            try store.remove(event, span: .thisEvent, commit: true)
            try? ActivityLog.write(tool: "calendar", cmd: "remove", desc: eventTitle, container: calName)
            let df = DateFormatter(); df.dateFormat = "EEE MMM d"
            print("Removed: \(eventTitle) (\(df.string(from: event.startDate)))")
        } catch {
            fail("Could not remove event: \(error.localizedDescription)")
        }
        semaphore.signal()

    default:
        // Try treating the bare command as a range shorthand: "calendar monday", "calendar 7d", etc.
        let rangeStr = args.joined(separator: " ")
        if let range = parseRange(rangeStr) {
            let events = fetchEvents(in: range, calendars: resolveCalendars(calFilter)).map(displayData)
            if events.isEmpty {
                print("No events — \(formatRangeDescription(range))")
            } else if range.isSingleDay {
                printFlat(events, showHeader: true, header: dayHeaderFormatter.string(from: range.start),
                          calFilter: calFilter)
            } else {
                printGrouped(events, calFilter: calFilter)
            }
        } else {
            usage()
        }
        semaphore.signal()
    }
}

semaphore.wait()

UpdateChecker.spawnBackgroundCheckIfNeeded()
if let hint = UpdateChecker.hint() { fputs(hint + "\n", stderr) }
