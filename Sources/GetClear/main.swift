// main.swift
//
// Entry point for the get-clear suite binary.
// Dispatches suite-level commands: what, setup, recap, update.

import Foundation
import EventKit
import GetClearKit

let args           = Array(CommandLine.arguments.dropFirst())
let displayVersion = versionString(tool: "get-clear", built: builtVersion, suite: suiteVersion)

guard let cmd = args.first else { usage() }
if isVersionFlag(cmd) { print(displayVersion); exit(0) }
if isHelpFlag(cmd)    { usage() }

switch cmd {

case "check-update":
    // Hidden subcommand — not in usage(). Called by UpdateChecker.spawnBackgroundCheckIfNeeded().
    // Hits the GitHub API and writes the update cache. Silent on success or failure.
    if let release = UpdateChecker.fetchLatestRelease(userAgent: "get-clear/\(builtVersion)") {
        UpdateChecker.writeCache(version: release.version, url: release.url)
    }
    exit(0)

case "what":
    UpdateChecker.spawnBackgroundCheckIfNeeded()
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
    if let hint = UpdateChecker.hint() { fputs(hint + "\n", stderr) }

case "update":
    guard let installed = UpdateChecker.installedVersion() else {
        print("get-clear update is only available for PKG installs.")
        print("Download from https://github.com/kscott/get-clear/releases")
        exit(0)
    }

    var latestVersion: String
    var downloadURL: String
    if let cached = UpdateChecker.cachedLatest(),
       Date().timeIntervalSince(cached.checked) < 3600 {
        latestVersion = cached.version
        downloadURL   = cached.url
    } else {
        print("Checking for latest version...")
        guard let fresh = UpdateChecker.fetchLatestRelease(userAgent: "get-clear/\(builtVersion)") else {
            fail("Could not reach GitHub. Check your connection and try again.")
        }
        UpdateChecker.writeCache(version: fresh.version, url: fresh.url)
        latestVersion = fresh.version
        downloadURL   = fresh.url
    }

    guard UpdateChecker.isNewer(latestVersion, than: installed) else {
        print("Already on the latest version (\(installed)).")
        exit(0)
    }

    print("Updating get-clear \(installed) → \(latestVersion)...")
    print("Downloading get-clear \(latestVersion)...")

    let pkgURL  = URL(string: downloadURL)!
    let tempPkg = URL(fileURLWithPath: "/tmp/get-clear-\(latestVersion).pkg")
    var downloadError: Error? = nil
    let dlSem = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: pkgURL) { data, _, error in
        defer { dlSem.signal() }
        if let error = error { downloadError = error; return }
        guard let data = data else { downloadError = NSError(domain: "get-clear", code: 1); return }
        do { try data.write(to: tempPkg, options: .atomic) }
        catch { downloadError = error }
    }.resume()
    dlSem.wait()

    if let error = downloadError {
        try? FileManager.default.removeItem(at: tempPkg)
        fail("Download failed: \(error.localizedDescription)")
    }

    print("Download complete.")
    print("A password will be required to complete installation.")

    let opener = Process()
    opener.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    opener.arguments = [tempPkg.path]
    try? opener.run()
    exit(0)

case "setup":
    UpdateChecker.spawnBackgroundCheckIfNeeded()
    if runSetup() { print("Try it: get-clear recap") }
    if let hint = UpdateChecker.hint() { fputs(hint + "\n", stderr) }

case "recap":
    UpdateChecker.spawnBackgroundCheckIfNeeded()
    var config = loadGetClearConfig()
    if !config.isRecapConfigured {
        print("First, choose which calendars to include in recap.\n")
        guard runSetup() else { exit(0) }
        config = loadGetClearConfig()
        guard config.isRecapConfigured else { exit(0) }
        print("")
    }

    let rangeStr = args.count > 1 ? Array(args.dropFirst()).joined(separator: " ") : "today"
    guard let range = parseRange(rangeStr) else { fail("Unrecognised range: \(rangeStr)") }
    let isToday = rangeStr == "today"

    // FR-018: for today, check if we should substitute a recent prior day
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

default:
    usage()
}
