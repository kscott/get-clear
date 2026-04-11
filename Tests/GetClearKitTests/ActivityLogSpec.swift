// ActivityLogSpec.swift
//
// Tests for GetClearKit ActivityLog and ActivityLogReader.

import Quick
import Nimble
import Foundation
import GetClearKit

final class ActivityLogSpec: QuickSpec {
    override class func spec() {
        let cal = Calendar.current

        // MARK: - ActivityLog

        describe("ActivityLog.write") {
            context("file creation") {
                var tempDir: URL!

                beforeEach {
                    tempDir = FileManager.default.temporaryDirectory
                        .appendingPathComponent("gc-test-\(UUID().uuidString)")
                    try? ActivityLog.write(tool: "reminders", cmd: "done", desc: "Call Sarah",
                                           container: "Ibotta", baseDirectory: tempDir)
                }

                it("creates the log directory") {
                    expect(FileManager.default.fileExists(atPath: tempDir.path)) == true
                }
                it("creates today's log file") {
                    let today = ISO8601DateFormatter.logFileDateString(Date())
                    let file = tempDir.appendingPathComponent("\(today).log")
                    expect(FileManager.default.fileExists(atPath: file.path)) == true
                }
            }

            context("entry content") {
                var tempDir: URL!
                var entry: ActivityLogEntry?

                beforeEach {
                    tempDir = FileManager.default.temporaryDirectory
                        .appendingPathComponent("gc-test-\(UUID().uuidString)")
                    try? ActivityLog.write(tool: "reminders", cmd: "done", desc: "Call Sarah",
                                           container: "Ibotta", baseDirectory: tempDir)
                    let today = ISO8601DateFormatter.logFileDateString(Date())
                    let file = tempDir.appendingPathComponent("\(today).log")
                    let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
                    let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
                    let data = Data(lines[0].utf8)
                    entry = try? JSONDecoder.logDecoder().decode(ActivityLogEntry.self, from: data)
                }

                it("writes exactly one line") {
                    let today = ISO8601DateFormatter.logFileDateString(Date())
                    let file = tempDir.appendingPathComponent("\(today).log")
                    let lines = ((try? String(contentsOf: file, encoding: .utf8)) ?? "")
                        .split(separator: "\n", omittingEmptySubsequences: true)
                    expect(lines.count) == 1
                }
                it("parses as ActivityLogEntry") {
                    expect(entry).toNot(beNil())
                }
                it("records the correct tool") {
                    expect(entry?.tool) == "reminders"
                }
                it("records the correct command") {
                    expect(entry?.cmd) == "done"
                }
                it("records the correct description") {
                    expect(entry?.desc) == "Call Sarah"
                }
                it("records the correct container") {
                    expect(entry?.container) == "Ibotta"
                }
                it("timestamp is recent") {
                    expect(entry.map { abs($0.ts.timeIntervalSinceNow) < 5 }) == true
                }
            }

            context("nil container") {
                var tempDir: URL!

                beforeEach {
                    tempDir = FileManager.default.temporaryDirectory
                        .appendingPathComponent("gc-test-\(UUID().uuidString)")
                    try? ActivityLog.write(tool: "mail", cmd: "send", desc: "Alex Re: notes",
                                           container: nil, baseDirectory: tempDir)
                }

                it("serializes container as null in JSON") {
                    let today = ISO8601DateFormatter.logFileDateString(Date())
                    let file = tempDir.appendingPathComponent("\(today).log")
                    let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
                    expect(content).to(contain("\"container\":null"))
                }
                it("round-trips as nil after decode") {
                    let today = ISO8601DateFormatter.logFileDateString(Date())
                    let file = tempDir.appendingPathComponent("\(today).log")
                    let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
                    let data = Data(content.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
                    let decoded = try? JSONDecoder.logDecoder().decode(ActivityLogEntry.self, from: data)
                    expect(decoded?.container).to(beNil())
                }
            }

            context("appending") {
                var tempDir: URL!
                var lines: [Substring]!

                beforeEach {
                    tempDir = FileManager.default.temporaryDirectory
                        .appendingPathComponent("gc-test-\(UUID().uuidString)")
                    try? ActivityLog.write(tool: "reminders", cmd: "add",  desc: "First",  container: nil, baseDirectory: tempDir)
                    try? ActivityLog.write(tool: "reminders", cmd: "done", desc: "Second", container: nil, baseDirectory: tempDir)
                    let today = ISO8601DateFormatter.logFileDateString(Date())
                    let file = tempDir.appendingPathComponent("\(today).log")
                    lines = ((try? String(contentsOf: file, encoding: .utf8)) ?? "")
                        .split(separator: "\n", omittingEmptySubsequences: true)
                }

                it("writes both entries") {
                    expect(lines.count) == 2
                }
                it("preserves entry order") {
                    expect(lines.first?.contains("\"First\"")) == true
                    expect(lines.last?.contains("\"Second\"")) == true
                }
            }
        }

        // MARK: - ActivityLogReader

        describe("ActivityLogReader") {
            func makeTimestamp(addingHours hours: Double) -> String {
                let dayStart = cal.startOfDay(for: Date())
                return ISO8601DateFormatter().string(from: dayStart.addingTimeInterval(hours * 3600))
            }

            context("filtering by tool") {
                var tempDir: URL!
                var todayRange: ParsedRange!

                beforeEach {
                    tempDir = FileManager.default.temporaryDirectory
                        .appendingPathComponent("gc-test-\(UUID().uuidString)")
                    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                    let today = ISO8601DateFormatter.logFileDateString(Date())
                    let file = tempDir.appendingPathComponent("\(today).log")
                    let ts1 = makeTimestamp(addingHours: 8)
                    let ts2 = makeTimestamp(addingHours: 9)
                    let ts3 = makeTimestamp(addingHours: 10)
                    let content = [
                        #"{"ts":"\#(ts1)","tool":"reminders","cmd":"done","desc":"Call Sarah","container":"Ibotta"}"#,
                        #"{"ts":"\#(ts2)","tool":"mail","cmd":"send","desc":"Alex Re: notes","container":null}"#,
                        #"{"ts":"\#(ts3)","tool":"reminders","cmd":"add","desc":"Review PR","container":"Ibotta"}"#,
                    ].joined(separator: "\n") + "\n"
                    try? content.write(to: file, atomically: true, encoding: .utf8)
                    todayRange = parseRange("today")
                }

                it("reads all 3 entries when no tool filter") {
                    let all = ActivityLogReader.entries(in: todayRange.start...todayRange.end, tool: nil, baseDirectory: tempDir)
                    expect(all.count) == 3
                }
                it("filters to reminders entries only") {
                    let rem = ActivityLogReader.entries(in: todayRange.start...todayRange.end, tool: "reminders", baseDirectory: tempDir)
                    expect(rem.count) == 2
                }
                it("filters to mail entries only") {
                    let mail = ActivityLogReader.entries(in: todayRange.start...todayRange.end, tool: "mail", baseDirectory: tempDir)
                    expect(mail.count) == 1
                }
            }

            context("malformed lines") {
                var entries: [ActivityLogEntry]!

                beforeEach {
                    let tempDir = FileManager.default.temporaryDirectory
                        .appendingPathComponent("gc-test-\(UUID().uuidString)")
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
                        #"{"ts":"\#(tsBad2)","tool":"reminders","cmd":"done","desc":"","container":null}"#,
                    ].joined(separator: "\n") + "\n"
                    try? content.write(to: file, atomically: true, encoding: .utf8)
                    let range = parseRange("today")!
                    entries = ActivityLogReader.entries(in: range.start...range.end, tool: nil, baseDirectory: tempDir)
                }

                it("only the valid entry survives") {
                    expect(entries.count) == 1
                }
                it("the surviving entry has the expected description") {
                    expect(entries.first?.desc) == "Good entry"
                }
            }

            context("FR-018 recency rule") {
                it("shows yesterday's entry when last activity was within 3 hours") {
                    let now = Date()
                    let twoHoursAgo = now.addingTimeInterval(-2 * 3600)
                    let tempDir = FileManager.default.temporaryDirectory
                        .appendingPathComponent("gc-test-\(UUID().uuidString)")
                    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                    let yesterdayStr = ISO8601DateFormatter.logFileDateString(
                        cal.date(byAdding: .day, value: -1, to: now)!)
                    let file = tempDir.appendingPathComponent("\(yesterdayStr).log")
                    let tsStr = ISO8601DateFormatter().string(from: twoHoursAgo)
                    let line = #"{"ts":"\#(tsStr)","tool":"reminders","cmd":"done","desc":"Late night task","container":null}"# + "\n"
                    try? line.write(to: file, atomically: true, encoding: .utf8)
                    let todayRange = parseRange("today")!
                    let result = ActivityLogReader.entriesForDisplay(
                        in: todayRange.start...todayRange.end,
                        now: now,
                        baseDirectory: tempDir)
                    expect(result.entries.count) == 1
                }
                it("reports yesterday's date when showing recent entry") {
                    let now = Date()
                    let twoHoursAgo = now.addingTimeInterval(-2 * 3600)
                    let tempDir = FileManager.default.temporaryDirectory
                        .appendingPathComponent("gc-test-\(UUID().uuidString)")
                    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                    let yesterdayStr = ISO8601DateFormatter.logFileDateString(
                        cal.date(byAdding: .day, value: -1, to: now)!)
                    let file = tempDir.appendingPathComponent("\(yesterdayStr).log")
                    let tsStr = ISO8601DateFormatter().string(from: twoHoursAgo)
                    let line = #"{"ts":"\#(tsStr)","tool":"reminders","cmd":"done","desc":"Late night task","container":null}"# + "\n"
                    try? line.write(to: file, atomically: true, encoding: .utf8)
                    let todayRange = parseRange("today")!
                    let result = ActivityLogReader.entriesForDisplay(
                        in: todayRange.start...todayRange.end,
                        now: now,
                        baseDirectory: tempDir)
                    expect(cal.isDateInToday(result.dateUsed)) == false
                }
                it("does not trigger when last activity was more than 3 hours ago") {
                    let now = Date()
                    let fourHoursAgo = now.addingTimeInterval(-4 * 3600)
                    let tempDir = FileManager.default.temporaryDirectory
                        .appendingPathComponent("gc-test-\(UUID().uuidString)")
                    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                    let yesterdayStr = ISO8601DateFormatter.logFileDateString(
                        cal.date(byAdding: .day, value: -1, to: now)!)
                    let file = tempDir.appendingPathComponent("\(yesterdayStr).log")
                    let tsStr = ISO8601DateFormatter().string(from: fourHoursAgo)
                    let line = #"{"ts":"\#(tsStr)","tool":"reminders","cmd":"done","desc":"Old task","container":null}"# + "\n"
                    try? line.write(to: file, atomically: true, encoding: .utf8)
                    let todayRange = parseRange("today")!
                    let result = ActivityLogReader.entriesForDisplay(
                        in: todayRange.start...todayRange.end,
                        now: now,
                        baseDirectory: tempDir)
                    expect(result.entries).to(beEmpty())
                }
            }
        }
    }
}
