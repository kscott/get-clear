// main.swift
//
// Entry point for the get-clear suite binary.
// Dispatches suite-level commands: what, recap.

import Foundation
import GetClearKit

let version = "1.0.0"
let args    = Array(CommandLine.arguments.dropFirst())

func usage() -> Never {
    print("""
    get-clear \(version) — Your commitments, your contacts, your communications

    Usage:
      get-clear what [range]          # Everything across all tools
      get-clear recap [range]         # Where you showed up (coming soon)

    Feedback: https://github.com/kscott/get-clear/issues
    """)
    exit(0)
}

guard let cmd = args.first else { usage() }
if isVersionFlag(cmd) { print(version); exit(0) }
if isHelpFlag(cmd)    { usage() }

switch cmd {

case "what":
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

case "recap":
    fail("recap coming soon")

default:
    usage()
}
