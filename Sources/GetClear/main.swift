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
    handleWhat(args: args)

case "update":
    handleUpdate()

case "setup":
    handleSetup()

case "recap":
    handleRecap(args: args)

default:
    usage()
}
