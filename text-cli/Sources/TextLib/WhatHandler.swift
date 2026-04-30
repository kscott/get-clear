// WhatHandler.swift
// Handles the `text what` command — activity log display for the text tool.

import Foundation
import GetClearKit

public func handleWhat(args: [String]) -> String {
    let rangeStr = args.count > 1 ? Array(args.dropFirst()).joined(separator: " ") : "today"
    guard let range = parseRange(rangeStr) else { return "Unrecognised range: \(rangeStr)" }
    let entries: [ActivityLogEntry]
    let dateUsed: Date
    if rangeStr == "today" {
        let result = ActivityLogReader.entriesForDisplay(in: range.start ... range.end)
        entries = result.entries
        dateUsed = result.dateUsed
    } else {
        entries = ActivityLogReader.entries(in: range.start ... range.end, tool: "text")
        dateUsed = Date()
    }
    return ActivityLogFormatter.perToolWhat(
        entries: entries, range: range, rangeStr: rangeStr, tool: "text", dateUsed: dateUsed
    )
}
