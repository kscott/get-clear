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
    /// Requests EventKit access internally.
    /// - Parameter calendarNames: Calendar names to include. nil = all non-system calendars.
    public static func fetch(
        in range: ClosedRange<Date>,
        store: EKEventStore,
        calendarNames: [String]?,
        baseDirectory: URL? = nil
    ) async -> RecapResult {
        async let calendarEvents     = fetchCalendarEvents(in: range, store: store, calendarNames: calendarNames)
        async let completedReminders = fetchCompletedReminders(in: range, store: store)

        let (events, reminders) = await (calendarEvents, completedReminders)

        // Sent entries from log (mail + text send commands; "sms" kept for backward compat)
        let logEntries = ActivityLogReader.entries(in: range, baseDirectory: baseDirectory)
        let sent = logEntries.filter {
            ($0.tool == "mail" || $0.tool == "sms" || $0.tool == "text") && $0.cmd == "send"
        }

        // Timespan from all log entries (FR-009d)
        let tsSpan = TimespanFormatter.timespan(from: logEntries)
        let timespanResult: TimespanResult? = tsSpan.map {
            TimespanResult(start: $0.start, end: $0.end)
        }

        var groups: [RecapGroup] = []
        if !events.isEmpty    { groups.append(.fromCalendar(events)) }
        if !reminders.isEmpty { groups.append(.tasksCompleted(reminders)) }
        if !sent.isEmpty      { groups.append(.sent(sent)) }

        return RecapResult(groups: groups, timespan: timespanResult)
    }

    private static func fetchCalendarEvents(
        in range: ClosedRange<Date>,
        store: EKEventStore,
        calendarNames: [String]?
    ) async -> [EKEvent] {
        guard (try? await store.requestFullAccessToEvents()) == true else { return [] }
        let calendars = resolveCalendars(names: calendarNames, store: store)
        return fetchPastEvents(in: range, store: store, calendars: calendars)
    }

    private static func fetchCompletedReminders(
        in range: ClosedRange<Date>,
        store: EKEventStore
    ) async -> [EKReminder] {
        guard (try? await store.requestFullAccessToReminders()) == true else { return [] }
        let pred = store.predicateForReminders(in: nil)
        let all: [EKReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: pred) { continuation.resume(returning: $0 ?? []) }
        }
        return all.filter { rem in
            guard rem.isCompleted, let cd = rem.completionDate else { return false }
            return cd >= range.lowerBound && cd <= range.upperBound
        }
    }

    // MARK: - Private

    /// Resolves calendar names to EKCalendar objects.
    /// If names is nil, returns all user calendars (local/CalDAV/Exchange — excludes Birthdays, Holidays).
    private static func resolveCalendars(names: [String]?, store: EKEventStore) -> [EKCalendar]? {
        let all = store.calendars(for: .event)
        guard let names = names else {
            // Default: all user-owned calendars (excludes birthday and subscription calendars)
            let user = all.filter {
                switch $0.type {
                case .local, .calDAV, .exchange: return true
                default: return false
                }
            }
            return user.isEmpty ? nil : user
        }
        let matched = all.filter { names.contains($0.title) }
        return matched.isEmpty ? nil : matched
    }

    /// Queries past calendar events per FR-015:
    /// - Timed events:   include if endDate <= now
    /// - All-day events: include if startDate's calendar date falls within range
    /// Deduplicates by eventIdentifier (matches calendar-cli's fetchEvents behaviour).
    private static func fetchPastEvents(
        in range: ClosedRange<Date>,
        store: EKEventStore,
        calendars: [EKCalendar]?
    ) -> [EKEvent] {
        let now = Date()
        let cal = Calendar.current
        let pred = store.predicateForEvents(
            withStart: range.lowerBound,
            end: range.upperBound,
            calendars: calendars
        )
        let sorted = store.events(matching: pred).sorted { $0.startDate < $1.startDate }

        // Deduplicate by eventIdentifier — same logic as calendar-cli's fetchEvents
        var seen = Set<String>()
        let deduped = sorted.filter { seen.insert($0.eventIdentifier).inserted }

        return deduped.filter { event in
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
