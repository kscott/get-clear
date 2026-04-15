// RecapCommand.swift
// Displays a recap of what happened across all Get Clear tools.

import Foundation
import EventKit
import GetClearKit

func handleRecap(args: [String]) {
    UpdateChecker.spawnBackgroundCheckIfNeeded()
    var config = loadGetClearConfig()
    if !config.isRecapConfigured {
        print("First, choose which calendars to include in recap.\n")
        guard handleSetup() else { exit(0) }
        config = loadGetClearConfig()
        guard config.isRecapConfigured else { exit(0) }
        print("")
    }

    let rangeStr = args.count > 1 ? Array(args.dropFirst()).joined(separator: " ") : "today"
    guard let range = parseRange(rangeStr) else { fail("Unrecognised range: \(rangeStr)") }
    let isToday = rangeStr == "today"

    // FR-018: for today, substitute the most recent active day if today has no entries yet
    var effectiveRange = range.start...range.end
    var dateUsed       = range.start
    if isToday {
        let logResult = ActivityLogReader.entriesForDisplay(in: range.start...range.end)
        dateUsed = logResult.dateUsed
        if !Calendar.current.isDateInToday(dateUsed) {
            let cal      = Calendar.current
            let dayStart = cal.startOfDay(for: dateUsed)
            let dayEnd   = cal.date(byAdding: .day, value: 1, to: dayStart)!.addingTimeInterval(-1)
            effectiveRange = dayStart...dayEnd
        }
    }

    let sem   = DispatchSemaphore(value: 0)
    let store = EKEventStore()
    RecapAggregator.fetch(in: effectiveRange, store: store,
                          calendarNames: config.recapCalendars) { result in
        print(formatRecap(result, range: range, rangeStr: rangeStr,
                          isToday: isToday, dateUsed: dateUsed))
        sem.signal()
    }
    sem.wait()
    if let hint = UpdateChecker.hint() { fputs(hint + "\n", stderr) }
}
