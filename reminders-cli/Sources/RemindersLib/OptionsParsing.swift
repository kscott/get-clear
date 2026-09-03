// OptionsParsing.swift
//
// Maps a ParsedCommand (from GetClearKit's shared parser) onto the reminders domain DTO.
// No EventKit dependency — lives in RemindersLib so it can be unit tested.

import GetClearKit

public struct ParsedOptions {
    public var date: String = ""
    public var recurrence: String = ""
    public var priority: String = ""
    public var note: String = ""
    public var url: String = ""
    public var list: String = ""

    public init() {}
}

/// Maps a shared-parser result onto the reminders domain fields.
public func parseOptions(from parsed: ParsedCommand) -> ParsedOptions {
    var result = ParsedOptions()
    result.date = parsed.bareDateRange ?? parsed.values["due"] ?? ""
    result.recurrence = parsed.values["repeat"] ?? ""
    result.priority = parsed.values["priority"] ?? ""
    result.url = parsed.values["url"] ?? ""
    result.list = parsed.values["list"] ?? ""
    result.note = parsed.trailingText ?? ""
    return result
}
