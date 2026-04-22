// WhatCommand.swift
// Displays today's activity across all Get Clear tools.

import Foundation
import GetClearKit

func handleWhat(args: [String]) async {
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
        entries = ActivityLogReader.entries(in: range.start...range.end)
    }
    print(ActivityLogFormatter.suiteWhat(entries: entries, range: range, rangeStr: rangeStr,
                                         dateUsed: dateUsed))
}
