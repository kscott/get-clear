// ActivityLogSpec.swift
//
// Tests for GetClearKit ActivityLog and ActivityLogReader.

import Foundation
import GetClearKit
import Testing

private let cal = Calendar.current

private func uniqueTempDir() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("gc-test-\(UUID().uuidString)")
}

private func makeTimestamp(addingHours hours: Double) -> String {
    let dayStart = cal.startOfDay(for: Date())
    return ISO8601DateFormatter().string(from: dayStart.addingTimeInterval(hours * 3600))
}

@Suite("ActivityLog.write")
struct ActivityLogWriteTests {
    @Suite("file creation")
    struct FileCreation {
        let tempDir = uniqueTempDir()

        init() {
            try? ActivityLog.write(tool: "reminders", cmd: "done", desc: "Call Sarah",
                                   container: "Ibotta", baseDirectory: tempDir)
        }

        @Test("creates the log directory")
        func createsDirectory() {
            #expect(FileManager.default.fileExists(atPath: tempDir.path))
        }

        @Test("creates today's log file")
        func createsTodaysFile() {
            let today = ISO8601DateFormatter.logFileDateString(Date())
            let file = tempDir.appendingPathComponent("\(today).log")
            #expect(FileManager.default.fileExists(atPath: file.path))
        }
    }

    @Suite("entry content")
    struct EntryContent {
        let tempDir = uniqueTempDir()
        let file: URL
        let entry: ActivityLogEntry?

        init() {
            try? ActivityLog.write(tool: "reminders", cmd: "done", desc: "Call Sarah",
                                   container: "Ibotta", baseDirectory: tempDir)
            let today = ISO8601DateFormatter.logFileDateString(Date())
            file = tempDir.appendingPathComponent("\(today).log")
            let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
            entry = lines.first.flatMap { try? JSONDecoder.logDecoder().decode(ActivityLogEntry.self, from: Data($0.utf8)) }
        }

        @Test("writes exactly one line")
        func writesOneLine() {
            let lines = ((try? String(contentsOf: file, encoding: .utf8)) ?? "")
                .split(separator: "\n", omittingEmptySubsequences: true)
            #expect(lines.count == 1)
        }

        @Test("parses as ActivityLogEntry") func parses() {
            #expect(entry != nil)
        }

        @Test("records the correct tool") func tool() {
            #expect(entry?.tool == "reminders")
        }

        @Test("records the correct command") func cmd() {
            #expect(entry?.cmd == "done")
        }

        @Test("records the correct description") func desc() {
            #expect(entry?.desc == "Call Sarah")
        }

        @Test("records the correct container") func container() {
            #expect(entry?.container == "Ibotta")
        }

        @Test("timestamp is recent")
        func timestampRecent() throws {
            let e = try #require(entry)
            #expect(abs(e.ts.timeIntervalSinceNow) < 5)
        }
    }

    @Suite("nil container")
    struct NilContainer {
        let tempDir = uniqueTempDir()
        let file: URL

        init() {
            try? ActivityLog.write(tool: "mail", cmd: "send", desc: "Alex Re: notes",
                                   container: nil, baseDirectory: tempDir)
            let today = ISO8601DateFormatter.logFileDateString(Date())
            file = tempDir.appendingPathComponent("\(today).log")
        }

        @Test("serializes container as null in JSON")
        func serializesNull() {
            let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            #expect(content.contains("\"container\":null"))
        }

        @Test("round-trips as nil after decode")
        func roundTripsNil() {
            let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            let data = Data(content.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
            let decoded = try? JSONDecoder.logDecoder().decode(ActivityLogEntry.self, from: data)
            #expect(decoded?.container == nil)
        }
    }

    @Suite("appending")
    struct Appending {
        let lines: [Substring]

        init() {
            let tempDir = uniqueTempDir()
            try? ActivityLog.write(tool: "reminders", cmd: "add", desc: "First", container: nil, baseDirectory: tempDir)
            try? ActivityLog.write(tool: "reminders", cmd: "done", desc: "Second", container: nil, baseDirectory: tempDir)
            let today = ISO8601DateFormatter.logFileDateString(Date())
            let file = tempDir.appendingPathComponent("\(today).log")
            lines = ((try? String(contentsOf: file, encoding: .utf8)) ?? "")
                .split(separator: "\n", omittingEmptySubsequences: true)
        }

        @Test("writes both entries") func writesBoth() {
            #expect(lines.count == 2)
        }

        @Test("preserves entry order")
        func preservesOrder() {
            #expect(lines.first?.contains("\"First\"") == true)
            #expect(lines.last?.contains("\"Second\"") == true)
        }
    }
}

@Suite("ActivityLogReader")
struct ActivityLogReaderTests {
    @Suite("filtering by tool")
    struct FilteringByTool {
        let tempDir = uniqueTempDir()
        let todayRange: ParsedRange?

        init() {
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let today = ISO8601DateFormatter.logFileDateString(Date())
            let file = tempDir.appendingPathComponent("\(today).log")
            let ts1 = makeTimestamp(addingHours: 8)
            let ts2 = makeTimestamp(addingHours: 9)
            let ts3 = makeTimestamp(addingHours: 10)
            let content = [
                #"{"ts":"\#(ts1)","tool":"reminders","cmd":"done","desc":"Call Sarah","container":"Ibotta"}"#,
                #"{"ts":"\#(ts2)","tool":"mail","cmd":"send","desc":"Alex Re: notes","container":null}"#,
                #"{"ts":"\#(ts3)","tool":"reminders","cmd":"add","desc":"Review PR","container":"Ibotta"}"#
            ].joined(separator: "\n") + "\n"
            try? content.write(to: file, atomically: true, encoding: .utf8)
            todayRange = parseRange("today")
        }

        @Test("reads all 3 entries when no tool filter")
        func readsAllThree() {
            guard let range = todayRange else { return }
            let all = ActivityLogReader.entries(in: range.start ... range.end, tool: nil, baseDirectory: tempDir)
            #expect(all.count == 3)
        }

        @Test("filters to reminders entries only")
        func filtersReminders() {
            guard let range = todayRange else { return }
            let rem = ActivityLogReader.entries(in: range.start ... range.end, tool: "reminders", baseDirectory: tempDir)
            #expect(rem.count == 2)
        }

        @Test("filters to mail entries only")
        func filtersMail() {
            guard let range = todayRange else { return }
            let mail = ActivityLogReader.entries(in: range.start ... range.end, tool: "mail", baseDirectory: tempDir)
            #expect(mail.count == 1)
        }
    }

    @Suite("malformed lines")
    struct MalformedLines {
        let entries: [ActivityLogEntry]

        init() {
            let tempDir = uniqueTempDir()
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let today = ISO8601DateFormatter.logFileDateString(Date())
            let file = tempDir.appendingPathComponent("\(today).log")
            let tsGood = makeTimestamp(addingHours: 8)
            let tsBad1 = makeTimestamp(addingHours: 9)
            let tsBad2 = makeTimestamp(addingHours: 10)
            let content = [
                #"not json at all"#,
                #"{"ts":"\#(tsGood)","tool":"reminders","cmd":"done","desc":"Good entry","container":null}"#,
                #"{"ts":"broken-date","tool":"reminders","cmd":"done","desc":"Bad ts","container":null}"#,
                #"{"ts":"\#(tsBad1)","tool":"unknown-tool","cmd":"done","desc":"Unknown tool","container":null}"#,
                #"{"ts":"\#(tsBad2)","tool":"reminders","cmd":"done","desc":"","container":null}"#
            ].joined(separator: "\n") + "\n"
            try? content.write(to: file, atomically: true, encoding: .utf8)
            let range = parseRange("today")!
            entries = ActivityLogReader.entries(in: range.start ... range.end, tool: nil, baseDirectory: tempDir)
        }

        @Test("only the valid entry survives") func onlyValidSurvives() {
            #expect(entries.count == 1)
        }

        @Test("the surviving entry has the expected description") func survivorDescription() {
            #expect(entries.first?.desc == "Good entry")
        }
    }

    @Suite("FR-018 recency rule")
    struct FR018RecencyRule {
        @Test("shows yesterday's entry when last activity was within 3 hours")
        func showsYesterdayWithinThreeHours() throws {
            let now = Date()
            let twoHoursAgo = now.addingTimeInterval(-2 * 3600)
            let tempDir = uniqueTempDir()
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let yesterdayStr = try ISO8601DateFormatter.logFileDateString(#require(cal.date(byAdding: .day, value: -1, to: now)))
            let file = tempDir.appendingPathComponent("\(yesterdayStr).log")
            let tsStr = ISO8601DateFormatter().string(from: twoHoursAgo)
            let line = #"{"ts":"\#(tsStr)","tool":"reminders","cmd":"done","desc":"Late night task","container":null}"# + "\n"
            try? line.write(to: file, atomically: true, encoding: .utf8)
            let todayRange = try #require(parseRange("today"))
            let result = ActivityLogReader.entriesForDisplay(
                in: todayRange.start ... todayRange.end, now: now, baseDirectory: tempDir
            )
            #expect(result.entries.count == 1)
        }

        @Test("reports yesterday's date when showing recent entry")
        func reportsYesterdaysDate() throws {
            let now = Date()
            let twoHoursAgo = now.addingTimeInterval(-2 * 3600)
            let tempDir = uniqueTempDir()
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let yesterdayStr = try ISO8601DateFormatter.logFileDateString(#require(cal.date(byAdding: .day, value: -1, to: now)))
            let file = tempDir.appendingPathComponent("\(yesterdayStr).log")
            let tsStr = ISO8601DateFormatter().string(from: twoHoursAgo)
            let line = #"{"ts":"\#(tsStr)","tool":"reminders","cmd":"done","desc":"Late night task","container":null}"# + "\n"
            try? line.write(to: file, atomically: true, encoding: .utf8)
            let todayRange = try #require(parseRange("today"))
            let result = ActivityLogReader.entriesForDisplay(
                in: todayRange.start ... todayRange.end, now: now, baseDirectory: tempDir
            )
            #expect(cal.isDateInToday(result.dateUsed) == false)
        }

        @Test("does not trigger when last activity was more than 3 hours ago")
        func doesNotTriggerAfterThreeHours() throws {
            let now = Date()
            let fourHoursAgo = now.addingTimeInterval(-4 * 3600)
            let tempDir = uniqueTempDir()
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let yesterdayStr = try ISO8601DateFormatter.logFileDateString(#require(cal.date(byAdding: .day, value: -1, to: now)))
            let file = tempDir.appendingPathComponent("\(yesterdayStr).log")
            let tsStr = ISO8601DateFormatter().string(from: fourHoursAgo)
            let line = #"{"ts":"\#(tsStr)","tool":"reminders","cmd":"done","desc":"Old task","container":null}"# + "\n"
            try? line.write(to: file, atomically: true, encoding: .utf8)
            let todayRange = try #require(parseRange("today"))
            let result = ActivityLogReader.entriesForDisplay(
                in: todayRange.start ... todayRange.end, now: now, baseDirectory: tempDir
            )
            #expect(result.entries.isEmpty)
        }
    }
}
