import Foundation
import GetClearKit

public func handleWhat(args: [String]) throws -> String {
    let rangeStr = args.count > 1 ? Array(args.dropFirst()).joined(separator: " ") : "today"
    guard let range = parseRange(rangeStr) else {
        throw ContactHandlerError.usage("Unrecognised range: \(rangeStr)")
    }
    let isToday = rangeStr == "today"
    var dateUsed = Date()
    let entries: [ActivityLogEntry]
    if isToday {
        let result = ActivityLogReader.entriesForDisplay(in: range.start ... range.end)
        entries = result.entries
        dateUsed = result.dateUsed
    } else {
        entries = ActivityLogReader.entries(in: range.start ... range.end, tool: "contacts")
    }
    return ActivityLogFormatter.perToolWhat(entries: entries, range: range, rangeStr: rangeStr,
                                            tool: "contacts", dateUsed: dateUsed)
}
