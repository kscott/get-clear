// main.swift
//
// Entry point for the calendar-bin executable.
// Handles argument parsing and all EventKit/AppKit interactions.
// Range and config parsing are delegated to CalendarLib so they can be unit tested.

import Foundation
import AppKit
import EventKit
import CalendarLib
import GetClearKit

let version = "1.0.0"

let store     = EKEventStore()
let semaphore = DispatchSemaphore(value: 0)
var args      = Array(CommandLine.arguments.dropFirst())

func usage() -> Never {
    print("""
    calendar \(version) — CLI for Apple Calendar

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

// MARK: - Calendar filter extraction (positional prefix)

let knownCommands: Set<String> = [
    "open", "calendars", "setup", "list", "today", "week", "next",
    "find", "show", "add", "remove",
    "help", "--help", "-h", "version", "--version", "-v"
]

/// If the first arg is a known config subset, extract it as the calendar filter.
/// `calendar work today` → calFilter = "work", args becomes ["today", ...]
var calFilter: String? = nil
if let first = args.first,
   !knownCommands.contains(first.lowercased()),
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

// MARK: - Output formatting

let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    return f
}()

let dayHeaderFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEEE, MMMM d"
    return f
}()

func formatTime(_ date: Date) -> String {
    timeFormatter.string(from: date)
}

/// Returns an ANSI true-color foreground escape for the calendar's color, or "" if unavailable.
/// Respects NO_COLOR and isatty — no color codes when piping output.
func calendarDot(_ calendar: EKCalendar) -> String {
    guard ANSI.enabled else { return "  " }
    guard let cg = calendar.cgColor else { return "  " }
    let colorSpace = cg.colorSpace?.model
    let components = cg.components ?? []
    let r, g, b: Int
    if colorSpace == .rgb, components.count >= 3 {
        r = Int(components[0] * 255)
        g = Int(components[1] * 255)
        b = Int(components[2] * 255)
    } else if colorSpace == .monochrome, components.count >= 1 {
        let w = Int(components[0] * 255)
        r = w; g = w; b = w
    } else {
        return "  "
    }
    return "\u{001B}[38;2;\(r);\(g);\(b)m●\u{001B}[0m "
}

func eventLine(_ event: EKEvent) -> String {
    let timeCol: String
    if event.isAllDay {
        timeCol = " All day              "
    } else {
        let start = formatTime(event.startDate)
        let end   = formatTime(event.endDate)
        timeCol = String(format: " %8@ – %-8@  ", start as CVarArg, end as CVarArg)
    }
    var label = ANSI.bold(event.title ?? "(no title)")
    if let loc = event.location, !loc.isEmpty {
        let firstLine = loc.components(separatedBy: "\n").first ?? loc
        let truncated = firstLine.count > 50 ? String(firstLine.prefix(50)) + "…" : firstLine
        label += ANSI.dim(" · " + truncated)
    }
    return "\(calendarDot(event.calendar))\(timeCol)\(label)"
}

func printGrouped(_ events: [EKEvent]) {
    let cal     = Calendar.current
    let grouped = Dictionary(grouping: events) { cal.startOfDay(for: $0.startDate) }
    let days    = grouped.keys.sorted()
    for (i, day) in days.enumerated() {
        if i > 0 { print("") }
        print(ANSI.bold(dayHeaderFormatter.string(from: day)))
        for event in (grouped[day] ?? []).sorted(by: { $0.startDate < $1.startDate }) {
            print(eventLine(event))
        }
    }
}

func printFlat(_ events: [EKEvent], showHeader: Bool, header: String) {
    if showHeader { print(header) }
    for event in events { print(eventLine(event)) }
}

func nextRelativeLabel(_ date: Date) -> String {
    let cal  = Calendar.current
    let now  = Date()
    if cal.isDateInToday(date)    { return "Today    " }
    if cal.isDateInTomorrow(date) { return "Tomorrow " }
    let days = cal.dateComponents([.day], from: cal.startOfDay(for: now),
                                          to: cal.startOfDay(for: date)).day ?? 99
    if days < 7 {
        let f = DateFormatter(); f.dateFormat = "EEE      "
        return f.string(from: date)
    }
    let f = DateFormatter(); f.dateFormat = "MMM d    "
    return f.string(from: date)
}

// MARK: - Event date/time parsing for `add`

/// Parses the arguments after the title for `calendar add`.
/// Handles:
///   "march 15"                 → all-day event on March 15
///   "tomorrow 2pm to 3pm"      → timed event, explicit end
///   "today 9:30am to 11am"     → timed event, explicit end
///   "monday at 2pm"            → 1-hour timed event
struct EventDateTime {
    let start:    Date
    let end:      Date
    let isAllDay: Bool
}

func parseEventDateTime(_ input: String) -> EventDateTime? {
    let cal = Calendar.current
    let now = Date()

    let timeRegex = try! NSRegularExpression(
        pattern: #"\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b"#, options: .caseInsensitive)
    let timeMatches = timeRegex.matches(in: input, range: NSRange(input.startIndex..., in: input))

    func extractHourMinute(_ m: NSTextCheckingResult) -> (Int, Int)? {
        guard let hourRange = Range(m.range(at: 1), in: input),
              let hour = Int(input[hourRange]) else { return nil }
        let minute: Int
        if let minRange = Range(m.range(at: 2), in: input) { minute = Int(input[minRange]) ?? 0 }
        else { minute = 0 }
        var h = hour
        if let apRange = Range(m.range(at: 3), in: input) {
            let ap = input[apRange].lowercased()
            if ap == "pm" && h < 12 { h += 12 }
            if ap == "am" && h == 12 { h = 0 }
        }
        return (h, minute)
    }

    if timeMatches.isEmpty {
        // All-day: parse entire input as a date
        guard let date = parseSingleDate(input.lowercased().trimmingCharacters(in: .whitespaces),
                                         cal: cal, now: now) else { return nil }
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: DateComponents(day: 1, second: -1), to: start)!
        return EventDateTime(start: start, end: end, isAllDay: true)
    }

    // Date part = everything before the first time token
    let firstTimeRange = Range(timeMatches[0].range, in: input)!
    let datePart = String(input[..<firstTimeRange.lowerBound])
        .replacingOccurrences(of: #"\bat\b"#, with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespaces)
    let baseDate: Date
    if datePart.isEmpty {
        baseDate = now
    } else {
        guard let d = parseSingleDate(datePart.lowercased(), cal: cal, now: now) else { return nil }
        baseDate = d
    }

    guard let (startH, startM) = extractHourMinute(timeMatches[0]) else { return nil }
    var startComps = cal.dateComponents([.year, .month, .day], from: baseDate)
    startComps.hour = startH; startComps.minute = startM
    let start = cal.date(from: startComps)!

    let end: Date
    if timeMatches.count >= 2, let (endH, endM) = extractHourMinute(timeMatches[1]) {
        var endComps = startComps
        endComps.hour = endH; endComps.minute = endM
        end = cal.date(from: endComps)!
    } else {
        end = cal.date(byAdding: .hour, value: 1, to: start)!
    }

    return EventDateTime(start: start, end: end, isAllDay: false)
}

// MARK: - Dispatch

guard let cmd = args.first else { usage() }
if isVersionFlag(cmd) { print(version); exit(0) }
if isHelpFlag(cmd)    { usage() }

store.requestFullAccessToEvents { granted, _ in
    guard granted else { fail("Calendar access denied") }

    switch cmd {

    case "open":
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
        semaphore.signal()

    case "calendars":
        let all = store.calendars(for: .event)
        let grouped = Dictionary(grouping: all) { $0.source.title }
        for source in grouped.keys.sorted() {
            print(source)
            for cal in (grouped[source] ?? []).sorted(by: { $0.title < $1.title }) {
                print("  \(calendarDot(cal))\(cal.title)")
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

        // Build numbered flat list
        var numberedCals: [(Int, EKCalendar)] = []
        var n = 1
        let grouped = Dictionary(grouping: all) { $0.source.title }
        print("Available calendars:\n")
        for source in grouped.keys.sorted() {
            print("  \(source)")
            for cal in (grouped[source] ?? []).sorted(by: { $0.title < $1.title }) {
                print(String(format: "    %2d  \(calendarDot(cal))\(cal.title)", n))
                numberedCals.append((n, cal))
                n += 1
            }
        }

        print("\nCreate subsets to group calendars (e.g. \"work\", \"personal\").")
        print("Enter calendar names or numbers, comma-separated. Press Enter with no name to finish.\n")

        var subsets: [(String, [String])] = []

        while true {
            print("Subset name: ", terminator: "")
            fflush(stdout)
            guard let nameInput = readLine() else { break }
            let subsetName = nameInput.trimmingCharacters(in: .whitespaces).lowercased()
            guard !subsetName.isEmpty else { break }

            print("Calendars for \"\(subsetName)\": ", terminator: "")
            fflush(stdout)
            guard let calInput = readLine(),
                  !calInput.trimmingCharacters(in: .whitespaces).isEmpty else {
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
                } else if let match = all.first(where: {
                    $0.title.lowercased() == token.lowercased()
                }) {
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
        let rangeStr  = args.dropFirst().joined(separator: " ")
        guard let range = parseRange(rangeStr) else { fail("unrecognised range: \(rangeStr)") }
        let calendars = resolveCalendars(calFilter)
        let events    = fetchEvents(in: range, calendars: calendars)
        if events.isEmpty {
            print("No events — \(formatRangeDescription(range))")
        } else if range.isSingleDay {
            printFlat(events, showHeader: true, header: dayHeaderFormatter.string(from: range.start))
        } else {
            printGrouped(events)
        }
        semaphore.signal()

    case "today":
        let range     = parseRange("today")!
        let calendars = resolveCalendars(calFilter)
        let events    = fetchEvents(in: range, calendars: calendars)
        let header    = dayHeaderFormatter.string(from: range.start)
        if events.isEmpty {
            print("\(header)\n  (nothing scheduled)")
        } else {
            printFlat(events, showHeader: true, header: header)
        }
        semaphore.signal()

    case "week":
        let range     = parseRange("week")!
        let calendars = resolveCalendars(calFilter)
        let events    = fetchEvents(in: range, calendars: calendars)
        if events.isEmpty {
            print("No events this week")
        } else {
            printGrouped(events)
        }
        semaphore.signal()

    case "next":
        let n: Int
        if args.count > 1, let num = Int(args[1]) {
            n = num
        } else {
            n = 5
        }
        let lookAhead = parseRange("90d")!
        let calendars = resolveCalendars(calFilter)
        let all       = fetchEvents(in: lookAhead, calendars: calendars)
        let now       = Date()
        let upcoming  = Array(all.filter { $0.endDate > now }.prefix(n))
        if upcoming.isEmpty {
            print("No upcoming events in the next 90 days")
        } else {
            for event in upcoming {
                let dateLabel = nextRelativeLabel(event.startDate)
                let timeStr   = event.isAllDay ? "All day  " : formatTime(event.startDate)
                var label     = event.title ?? "(no title)"
                if let loc = event.location, !loc.isEmpty {
                    label += " · " + (loc.components(separatedBy: "\n").first ?? loc)
                }
                print("\(calendarDot(event.calendar)) \(dateLabel)  \(timeStr)   \(label)")
            }
        }
        semaphore.signal()

    case "find":
        guard args.count > 1 else { fail("provide a search query") }
        let remaining  = Array(args.dropFirst())  // drop "find"

        // Try to find a trailing range argument — last token(s) that form a valid range
        var query: String
        var range: ParsedRange
        if remaining.count > 1,
           let r = parseRange(remaining.dropFirst().joined(separator: " ")) {
            query = remaining[0]
            range = r
        } else if remaining.count > 1,
                  let r = parseRange(remaining.last!) {
            query = remaining.dropLast().joined(separator: " ")
            range = r
        } else {
            query = remaining.joined(separator: " ")
            range = parseRange("30d")!
        }

        let calendars = resolveCalendars(calFilter)
        let events    = fetchEvents(in: range, calendars: calendars)
        let lower     = query.lowercased()
        let matches   = events.filter {
            ($0.title?.lowercased().contains(lower) ?? false) ||
            ($0.notes?.lowercased().contains(lower) ?? false)
        }

        if matches.isEmpty {
            print("No events matching '\(query)' in \(formatRangeDescription(range))")
        } else {
            printGrouped(matches)
        }
        semaphore.signal()

    case "show":
        guard args.count > 1 else { fail("provide an event title") }
        let title    = args[1]
        let rangeStr = args.count > 2 ? args.dropFirst(2).joined(separator: " ") : nil
        let range    = rangeStr.flatMap { parseRange($0) } ?? parseRange("30d")!

        let all      = store.calendars(for: .event)
        let events   = fetchEvents(in: range, calendars: all)
        let lower    = title.lowercased()
        let matches  = events.filter {
            ($0.title ?? "").caseInsensitiveCompare(title) == .orderedSame ||
            ($0.title ?? "").lowercased().contains(lower)
        }
        guard !matches.isEmpty else { fail("Not found: \(title)") }
        if matches.count > 1 {
            let df = DateFormatter(); df.dateFormat = "EEE MMM d"
            print("Multiple events match '\(title)':")
            for e in matches {
                let timeStr = e.isAllDay ? "all day" : formatTime(e.startDate)
                print("  \(df.string(from: e.startDate))  \(timeStr)  \(e.title ?? "")")
            }
            print("Add a date to narrow the search, e.g.: calendar show \"\(title)\" tomorrow")
            exit(1)
        }
        let event = matches[0]

        let cal = Calendar.current
        print(event.title ?? "(no title)")

        if event.isAllDay {
            let f = DateFormatter(); f.dateFormat = "EEE MMM d, yyyy"
            print("  Date:       \(f.string(from: event.startDate)) (all day)")
        } else {
            let df = DateFormatter(); df.dateFormat = "EEE MMM d, yyyy"
            let dateStr = df.string(from: event.startDate)
            let startStr = formatTime(event.startDate)
            let endStr   = formatTime(event.endDate)
            let sameDay  = cal.isDate(event.startDate, inSameDayAs: event.endDate)
            print("  Date:       \(dateStr), \(startStr) – \(sameDay ? endStr : df.string(from: event.endDate) + " " + endStr)")
        }

        print("  Calendar:   \(event.calendar.title)")

        if let loc = event.location, !loc.isEmpty {
            print("  Location:   \(loc)")
        }
        if let url = event.url {
            print("  URL:        \(url.absoluteString)")
        }
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
            if !names.isEmpty {
                print("  Attendees:  \(names.joined(separator: ", "))")
            }
        }
        if let notes = event.notes, !notes.isEmpty {
            let firstLine = notes.components(separatedBy: "\n").first ?? notes
            print("  Notes:      \(firstLine)")
            let rest = notes.components(separatedBy: "\n").dropFirst()
            for line in rest where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                print("              \(line)")
            }
        }

        semaphore.signal()

    case "add":
        guard args.count > 1 else { fail("provide an event title") }
        let title     = args[1]
        let dateStr   = Array(args.dropFirst(2)).joined(separator: " ")
        let calendars = resolveCalendars(calFilter)

        guard let edt = parseEventDateTime(dateStr.isEmpty ? "today" : dateStr) else {
            fail("unrecognised date/time: \(dateStr)")
        }

        // Pick calendar: first in resolved set
        guard let targetCal = calendars.first ?? store.defaultCalendarForNewEvents else {
            fail("no calendar available")
        }

        let event        = EKEvent(eventStore: store)
        event.title      = title
        event.calendar   = targetCal
        event.isAllDay   = edt.isAllDay
        event.startDate  = edt.start
        event.endDate    = edt.end

        do {
            try store.save(event, span: .thisEvent, commit: true)
            let df = DateFormatter()
            df.dateFormat = "EEE MMM d"
            let timeDetail = edt.isAllDay ? "all day" : "\(formatTime(edt.start)) – \(formatTime(edt.end))"
            print("Added: \(title) · \(df.string(from: edt.start)) \(timeDetail) (\(targetCal.title))")
        } catch {
            fail("Could not save event: \(error.localizedDescription)")
        }
        semaphore.signal()

    case "remove":
        guard args.count > 1 else { fail("provide an event title") }
        let title     = args[1]
        let rangeStr  = args.count > 2 ? Array(args.dropFirst(2)).joined(separator: " ") : nil
        let range     = rangeStr.flatMap { parseRange($0) } ?? parseRange("30d")!
        let calendars = resolveCalendars(calFilter)
        let events    = fetchEvents(in: range, calendars: calendars)
        let lower     = title.lowercased()
        let matches   = events.filter {
            ($0.title ?? "").caseInsensitiveCompare(title) == .orderedSame ||
            ($0.title ?? "").lowercased().contains(lower)
        }
        guard !matches.isEmpty else { fail("Not found: \(title)") }
        if matches.count > 1 {
            let df = DateFormatter(); df.dateFormat = "EEE MMM d"
            print("Multiple events match '\(title)':")
            for e in matches {
                let timeStr = e.isAllDay ? "all day" : formatTime(e.startDate)
                print("  \(df.string(from: e.startDate))  \(timeStr)  \(e.title ?? "")")
            }
            print("Add a date to narrow the search, e.g.: calendar remove \"\(title)\" tomorrow")
            exit(1)
        }
        let event = matches[0]
        do {
            try store.remove(event, span: .thisEvent, commit: true)
            let df = DateFormatter(); df.dateFormat = "EEE MMM d"
            print("Removed: \(event.title ?? "") (\(df.string(from: event.startDate)))")
        } catch {
            fail("Could not remove event: \(error.localizedDescription)")
        }
        semaphore.signal()

    default:
        // Try treating the bare command as a range shorthand: "calendar today", "calendar week",
        // "calendar monday", "calendar march 15", "calendar 7d", etc.
        let rangeStr   = args.joined(separator: " ")
        if let range = parseRange(rangeStr) {
            let calendars = resolveCalendars(calFilter)
            let events    = fetchEvents(in: range, calendars: calendars)
            if events.isEmpty {
                print("No events — \(formatRangeDescription(range))")
            } else if range.isSingleDay {
                printFlat(events, showHeader: true, header: dayHeaderFormatter.string(from: range.start))
            } else {
                printGrouped(events)
            }
        } else {
            usage()
        }
        semaphore.signal()
    }
}

semaphore.wait()
