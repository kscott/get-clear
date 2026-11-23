import CalendarLib
import Foundation
import GetClearKit
import RemindersLib

// MARK: - Types

public struct TimespanResult {
    public let start: Date
    public let end: Date?
}

public enum RecapGroup {
    case fromCalendar([EventItem])
    case tasksCompleted([ReminderItem])
    case sent([ActivityLogEntry])

    public var isEmpty: Bool {
        switch self {
        case let .fromCalendar(e): e.isEmpty
        case let .tasksCompleted(r): r.isEmpty
        case let .sent(e): e.isEmpty
        }
    }
}

public struct RecapResult {
    public let groups: [RecapGroup]
    public let timespan: TimespanResult?

    public var isEmpty: Bool {
        groups.isEmpty
    }
}

// MARK: - Aggregator

public enum RecapAggregator {
    /// Fetches the recap for the given date range. A store that is nil or can't be read
    /// contributes nothing, as before.
    /// - Parameter calendarNames: Calendar names to include. nil = the user's own calendars.
    static func fetch(
        in range: ClosedRange<Date>,
        calendars: (any CalendarStore)?,
        reminders: (any ReminderStore)?,
        calendarNames: [String]?,
        baseDirectory: URL? = nil
    ) async -> RecapResult {
        async let calendarEvents = fetchCalendarEvents(in: range, store: calendars, calendarNames: calendarNames)
        async let completedReminders = fetchCompletedReminders(in: range, store: reminders)

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
        if !events.isEmpty { groups.append(.fromCalendar(events)) }
        if !reminders.isEmpty { groups.append(.tasksCompleted(reminders)) }
        if !sent.isEmpty { groups.append(.sent(sent)) }

        return RecapResult(groups: groups, timespan: timespanResult)
    }

    /// Past events from the recap's calendars. The store returns them sorted and de-duplicated.
    private static func fetchCalendarEvents(
        in range: ClosedRange<Date>,
        store: (any CalendarStore)?,
        calendarNames: [String]?
    ) async -> [EventItem] {
        guard let store, let calendars = try? await store.fetchCalendars() else { return [] }
        let ids = recapCalendarIDs(names: calendarNames, from: calendars)
        let interval = DateInterval(start: range.lowerBound, end: range.upperBound)
        guard let events = try? await store.fetchEvents(in: interval, calendarIdentifiers: ids) else { return [] }
        return pastEvents(events, in: range, now: Date(), calendar: .current)
    }

    private static func fetchCompletedReminders(
        in range: ClosedRange<Date>,
        store: (any ReminderStore)?
    ) async -> [ReminderItem] {
        guard let store else { return [] }
        let interval = DateInterval(start: range.lowerBound, end: range.upperBound)
        return await (try? store.fetchCompleted(in: interval)) ?? []
    }
}
