// RecapCommand.swift
// Displays a recap of what happened across all Get Clear tools.

import EventKit
import Foundation
import GetClearKit

func handleRecap(args: [String]) async throws {
    var config = loadGetClearConfig()
    if !config.isRecapConfigured {
        print("First, choose which calendars to include in recap.\n")
        guard await pickAndSaveCalendars() else { exit(0) }
        config = loadGetClearConfig()
        guard config.isRecapConfigured else { exit(0) }
        print("")
    }

    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: GetClearCommandShapes.recap, wrapError: GetClearError.init
    )
    let rangeStr = parsed.bareDateRange ?? "today"
    guard let range = parseRange(rangeStr) else { throw GetClearError("Unrecognised range: \(rangeStr)") }
    let isToday = rangeStr == "today"

    // FR-018: early in the day there may be no log entries yet — show the last active day
    // so recap isn't empty when the user hasn't done anything in the current session
    var effectiveRange = range.start ... range.end
    var dateUsed = range.start
    if isToday {
        let logResult = ActivityLogReader.entriesForDisplay(in: range.start ... range.end)
        dateUsed = logResult.dateUsed
        if !Calendar.current.isDateInToday(dateUsed) {
            let cal = Calendar.current
            let dayStart = cal.startOfDay(for: dateUsed)
            // date(byAdding:) fails only on component overflow beyond Date's representable
            // range — essentially never for "add 1 day" — but a real crash serves no one here,
            // so fall back to the range already computed above instead of forcing it.
            if let nextDayStart = cal.date(byAdding: .day, value: 1, to: dayStart) {
                effectiveRange = dayStart ... nextDayStart.addingTimeInterval(-1)
            }
        }
    }

    let store = EKEventStore()
    let result = await RecapAggregator.fetch(in: effectiveRange, store: store,
                                             calendarNames: config.recapCalendars)
    print(formatRecap(result, range: range, rangeStr: rangeStr,
                      isToday: isToday, dateUsed: dateUsed))
}
