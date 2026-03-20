import Foundation
import EventKit
import GetClearKit

// MARK: - Types

public struct TimespanResult {
    public let start: Date
    public let end: Date?
}

public enum RecapGroup {
    case fromCalendar([EKEvent])
    case tasksCompleted([EKReminder])
    case sent([ActivityLogEntry])

    public var isEmpty: Bool {
        switch self {
        case .fromCalendar(let e):   return e.isEmpty
        case .tasksCompleted(let r): return r.isEmpty
        case .sent(let e):           return e.isEmpty
        }
    }
}

public struct RecapResult {
    public let groups: [RecapGroup]
    public let timespan: TimespanResult?

    public var isEmpty: Bool { groups.isEmpty }
}

// MARK: - Aggregator

public struct RecapAggregator {

    /// Fetches the recap for the given date range.
    /// Requests EventKit access internally. Calls completion on a background queue.
    public static func fetch(
        in range: ClosedRange<Date>,
        store: EKEventStore,
        baseDirectory: URL? = nil,
        completion: @escaping (RecapResult) -> Void
    ) {
        let group = DispatchGroup()
        var calendarEvents:      [EKEvent]    = []
        var completedReminders:  [EKReminder] = []

        // Calendar access
        group.enter()
        store.requestFullAccessToEvents { granted, _ in
            defer { group.leave() }
            guard granted else { return }
            calendarEvents = fetchPastEvents(in: range, store: store)
        }

        // Reminders access — fetchReminders is itself async so leave() goes in its callback
        group.enter()
        store.requestFullAccessToReminders { granted, _ in
            guard granted else { group.leave(); return }
            let pred = store.predicateForReminders(in: nil)
            store.fetchReminders(matching: pred) { reminders in
                completedReminders = (reminders ?? []).filter { rem in
                    guard rem.isCompleted, let cd = rem.completionDate else { return false }
                    return cd >= range.lowerBound && cd <= range.upperBound
                }
                group.leave()
            }
        }

        group.notify(queue: .global()) {
            // Sent entries from log (mail + sms send commands)
            let logEntries = ActivityLogReader.entries(in: range, baseDirectory: baseDirectory)
            let sent = logEntries.filter {
                ($0.tool == "mail" || $0.tool == "sms") && $0.cmd == "send"
            }

            // Timespan from all log entries (FR-009d)
            let tsSpan = TimespanFormatter.timespan(from: logEntries)
            let timespanResult: TimespanResult? = tsSpan.map {
                TimespanResult(start: $0.start, end: $0.end)
            }

            var groups: [RecapGroup] = []
            if !calendarEvents.isEmpty     { groups.append(.fromCalendar(calendarEvents)) }
            if !completedReminders.isEmpty { groups.append(.tasksCompleted(completedReminders)) }
            if !sent.isEmpty               { groups.append(.sent(sent)) }

            completion(RecapResult(groups: groups, timespan: timespanResult))
        }
    }

    // MARK: - Private

    /// Queries past calendar events per FR-015:
    /// - Timed events:   include if endDate <= now
    /// - All-day events: include if startDate's calendar date falls within range
    private static func fetchPastEvents(in range: ClosedRange<Date>, store: EKEventStore) -> [EKEvent] {
        let now = Date()
        let cal = Calendar.current
        let pred = store.predicateForEvents(
            withStart: range.lowerBound,
            end: range.upperBound,
            calendars: nil
        )
        return store.events(matching: pred).filter { event in
            if event.isAllDay {
                let eventDay   = cal.startOfDay(for: event.startDate)
                let rangeStart = cal.startOfDay(for: range.lowerBound)
                let rangeEnd   = cal.startOfDay(for: range.upperBound)
                return eventDay >= rangeStart && eventDay <= rangeEnd
            } else {
                return event.endDate <= now
            }
        }
    }
}
