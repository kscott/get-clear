// ShowCommand.swift

import Foundation
import EventKit
import CalendarLib
import GetClearKit

func handleShow(args: [String], store: EKEventStore, semaphore: DispatchSemaphore) {
    guard args.count > 1 else { fail("provide an event title") }
    let title    = args[1]
    let rangeStr = args.count > 2 ? args.dropFirst(2).joined(separator: " ") : nil
    let range    = rangeStr.flatMap { parseRange($0) } ?? parseRange("30d")!
    let lower    = title.lowercased()
    let matches  = fetchEvents(in: range, calendars: store.calendars(for: .event), store: store)
        .filter { ($0.title ?? "").caseInsensitiveCompare(title) == .orderedSame ||
                  ($0.title ?? "").lowercased().contains(lower) }
    guard !matches.isEmpty else { fail("Not found: \(title)") }
    if matches.count > 1 {
        let df = DateFormatter(); df.dateFormat = "EEE MMM d"
        print("Multiple events match '\(title)':")
        for e in matches {
            print("  \(df.string(from: e.startDate))  \(e.isAllDay ? "all day" : formatEventTime(e.startDate))  \(e.title ?? "")")
        }
        print("Add a date to narrow the search, e.g.: calendar show \"\(title)\" tomorrow")
        exit(1)
    }
    let e   = matches[0]
    let cal = Calendar.current
    print(e.title ?? "(no title)")
    if e.isAllDay {
        let f = DateFormatter(); f.dateFormat = "EEE MMM d, yyyy"
        print("  Date:       \(f.string(from: e.startDate)) (all day)")
    } else {
        let df      = DateFormatter(); df.dateFormat = "EEE MMM d, yyyy"
        let sameDay = cal.isDate(e.startDate, inSameDayAs: e.endDate)
        let endPart = sameDay ? formatEventTime(e.endDate)
                              : df.string(from: e.endDate) + " " + formatEventTime(e.endDate)
        print("  Date:       \(df.string(from: e.startDate)), \(formatEventTime(e.startDate)) – \(endPart)")
    }
    print("  Calendar:   \(e.calendar.title)")
    if let loc = e.location, !loc.isEmpty { print("  Location:   \(loc)") }
    if let url = e.url { print("  URL:        \(url.absoluteString)") }
    if let attendees = e.attendees, !attendees.isEmpty {
        let names = attendees.compactMap { p -> String? in
            guard let name = p.name else { return nil }
            let s: String
            switch p.participantStatus {
            case .accepted:  s = "accepted"
            case .declined:  s = "declined"
            case .tentative: s = "tentative"
            default:         s = "invited"
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
}
