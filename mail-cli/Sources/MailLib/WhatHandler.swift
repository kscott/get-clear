// WhatHandler.swift
// Handles the `mail what` command — reports recent mail activity from the log.

import Foundation
import GetClearKit

public func handleWhat(args: [String]) throws -> String {
    let range = try parseRange(trailingArgs: args, default: "today")
    let rangeStr = args.count > 1 ? Array(args.dropFirst()).joined(separator: " ") : "today"
    let isToday = rangeStr == "today"
    var dateUsed = Date()
    let entries: [ActivityLogEntry]
    if isToday {
        let result = ActivityLogReader.entriesForDisplay(in: range.start ... range.end)
        entries = result.entries
        dateUsed = result.dateUsed
    } else {
        entries = ActivityLogReader.entries(in: range.start ... range.end, tool: "mail")
    }
    return ActivityLogFormatter.perToolWhat(
        entries: entries, range: range, rangeStr: rangeStr, tool: "mail", dateUsed: dateUsed
    )
}
