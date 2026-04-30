// RecapCommand.swift
// Displays a recap of what happened across all Get Clear tools.

import EventKit
import Foundation
import GetClearKit

func handleRecap(args: [String]) async {
    var config = loadGetClearConfig()
    if !config.isRecapConfigured {
        print("First, choose which calendars to include in recap.\n")
        guard await pickAndSaveCalendars() else { exit(0) }
        config = loadGetClearConfig()
        guard config.isRecapConfigured else { exit(0) }
        print("")
    }

    let rangeStr = args.count > 1 ? Array(args.dropFirst()).joined(separator: " ") : "today"
    guard let range = parseRange(rangeStr) else { fail("Unrecognised range: \(rangeStr)") }
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
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!.addingTimeInterval(-1)
            effectiveRange = dayStart ... dayEnd
        }
    }

    let store = EKEventStore()
    let result = await RecapAggregator.fetch(in: effectiveRange, store: store,
                                             calendarNames: config.recapCalendars)
    print(formatRecap(result, range: range, rangeStr: rangeStr,
                      isToday: isToday, dateUsed: dateUsed))
}
