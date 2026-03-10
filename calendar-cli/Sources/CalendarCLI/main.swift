// main.swift
//
// Entry point for the calendar-bin executable.
// Handles argument parsing and all EventKit/AppKit interactions.
// Range and config parsing are delegated to CalendarLib so they can be unit tested.

import Foundation
import AppKit
import EventKit
import CalendarLib

let version = "1.0.0"

let store     = EKEventStore()
let semaphore = DispatchSemaphore(value: 0)
var args      = Array(CommandLine.arguments.dropFirst())

func fail(_ msg: String) -> Never {
    fputs("Error: \(msg)\n", stderr)
    exit(1)
}

func usage() -> Never {
    print("""
    calendar \(version) — CLI for Apple Calendar

    Usage:
      calendar open                               # Open the Calendar app
      calendar calendars                          # List all available calendars
      calendar list <range> [--cal <subset>]      # Events in range
      calendar today [--cal <subset>]             # Today's events
      calendar week [--cal <subset>]              # This week's events
      calendar next [n] [--cal <subset>]          # Next N events (default 5)
      calendar search <query> [range] [--cal <subset>]
      calendar show <title> [date]                # Full event detail

    Range examples:
      today, tomorrow, yesterday
      week, last week, next week
      month, last month, next month
      monday, friday                              (next occurrence, or today if today)
      "march 15", "2026-03-15"                   (specific date)
      "march 15 to march 20"                     (explicit range)
      "next monday to friday"                    (relative range)
      7d, 30d                                    (N days from today)

    Calendar filter (--cal):
      --cal work                                 (named subset from config)
      --cal "Work"                               (literal calendar name)

    Config: ~/.config/calendar-cli/config.toml
      [subsets]
      work     = ["Work", "Meetings"]
      personal = ["Home", "Family"]
    """)
    exit(0)
}

// MARK: - --cal flag extraction

if let idx = args.firstIndex(of: "--cal"), idx + 1 < args.count {
    // extracted below after config load
}

// MARK: - Helpers

let config = loadConfig()

func extractCalFilter() -> String? {
    guard let idx = args.firstIndex(of: "--cal"), idx + 1 < args.count else { return nil }
    let val = args[idx + 1]
    args.remove(at: idx + 1)
    args.remove(at: idx)
    return val
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
    return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
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

// MARK: - Color

/// Returns an ANSI true-color foreground escape for the calendar's color, or "" if unavailable.
/// Respects the NO_COLOR environment variable convention.
func calendarDot(_ calendar: EKCalendar) -> String {
    guard ProcessInfo.processInfo.environment["NO_COLOR"] == nil else { return "  " }
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
    var label = event.title ?? "(no title)"
    if let loc = event.location, !loc.isEmpty {
        label += " · " + (loc.components(separatedBy: "\n").first ?? loc)
    }
    return "\(calendarDot(event.calendar))\(timeCol)\(label)"
}

func printGrouped(_ events: [EKEvent]) {
    let cal     = Calendar.current
    let grouped = Dictionary(grouping: events) { cal.startOfDay(for: $0.startDate) }
    let days    = grouped.keys.sorted()
    for (i, day) in days.enumerated() {
        if i > 0 { print("") }
        print(dayHeaderFormatter.string(from: day))
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

// MARK: - Dispatch

guard let cmd = args.first else { usage() }
if cmd == "--version" || cmd == "-v" || cmd == "version" { print(version); exit(0) }
if cmd == "--help"    || cmd == "-h" || cmd == "help"    { usage() }

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

    case "list":
        guard args.count > 1 else { fail("provide a range (e.g. today, week, 7d, \"march 15 to march 20\")") }
        let calFilter = extractCalFilter()
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
        let calFilter = extractCalFilter()
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
        let calFilter = extractCalFilter()
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
        let calFilter = extractCalFilter()
        let n: Int
        if args.count > 1, let num = Int(args[1]) {
            n = num
        } else {
            n = 5
        }
        let lookAhead = parseRange("90d")!
        let calendars = resolveCalendars(calFilter)
        let all       = fetchEvents(in: lookAhead, calendars: calendars)
        let upcoming  = Array(all.prefix(n))
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

    case "search":
        guard args.count > 1 else { fail("provide a search query") }
        let calFilter  = extractCalFilter()
        let remaining  = Array(args.dropFirst())

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
        guard let event = events.first(where: {
            ($0.title ?? "").caseInsensitiveCompare(title) == .orderedSame ||
            ($0.title ?? "").lowercased().contains(title.lowercased())
        }) else {
            fail("Not found: \(title)")
        }

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

    default:
        // Try treating the bare command as a range shorthand: "calendar today", "calendar week",
        // "calendar monday", "calendar march 15", "calendar 7d", etc.
        let calFilter  = extractCalFilter()
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
