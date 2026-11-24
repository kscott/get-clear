// SelfUpdater.swift
//
// Replaces the installed Get Clear.app with a newer release, with no Installer and no password
// (spec 018 R8). Downloads the notarized app archive next to the installed app, verifies it is
// Get Clear's, signed by its developer and notarized, then swaps the two bundles in one atomic
// rename and restarts the helper. Every exit path removes what it downloaded.

import Foundation
import GetClearKit
import Security

enum SelfUpdater {
    /// The installed app must be Get Clear, signed by its developer, and notarized (FR-017).
    static let requirement = """
    anchor apple generic and identifier "com.kenscott.get-clear" \
    and certificate leaf[subject.OU] = "6Q96Q79QN8" and notarized
    """

    static func install(over app: InstalledApp, version: String, from asset: URL) async throws {
        let unchanged = "Your current version (\(app.version)) is unchanged."
        let fm = FileManager.default
        // Staging sits beside the app so the final swap is a rename within one folder.
        let staging = app.url.deletingLastPathComponent().appendingPathComponent(".get-clear-update-\(UUID().uuidString)")
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: staging) }

        progress("Downloading Get Clear \(version)…")
        let archive = staging.appendingPathComponent("Get-Clear.zip")
        do {
            let (downloaded, _) = try await URLSession.shared.download(from: asset)
            try fm.moveItem(at: downloaded, to: archive)
        } catch {
            throw GetClearError("Couldn't download the update: \(error.localizedDescription). \(unchanged)")
        }
        guard run("/usr/bin/ditto", ["-x", "-k", archive.path, staging.path]) == 0 else {
            throw GetClearError("Couldn't unpack the update. \(unchanged)")
        }
        let staged = staging.appendingPathComponent("Get Clear.app")

        progress("Verifying signature…")
        guard isGenuine(staged) else {
            throw GetClearError("The downloaded update isn't signed by Get Clear's developer — not installed. \(unchanged)")
        }
        let stagedVersion = (NSDictionary(contentsOf: staged.appendingPathComponent("Contents/Info.plist")) as? [String: Any])
            .flatMap(UpdateChecker.appVersion(fromInfo:))
        guard let stagedVersion, UpdateChecker.isNewer(stagedVersion, than: app.version) else {
            throw GetClearError("The downloaded update isn't newer than \(app.version) — not installed. \(unchanged)")
        }

        progress("Installing…")
        // Move the new app next to the installed one, then swap them: at every instant one complete
        // app is at the installed path (FR-018).
        let beside = app.url.deletingLastPathComponent().appendingPathComponent(".Get Clear \(UUID().uuidString).app")
        try fm.moveItem(at: staged, to: beside)
        guard renamex_np(beside.path, app.url.path, UInt32(RENAME_SWAP)) == 0 else {
            let reason = String(cString: strerror(errno))
            try? fm.removeItem(at: beside)
            throw GetClearError("Couldn't replace Get Clear: \(reason). \(unchanged)")
        }
        try? fm.removeItem(at: beside) // now the previous version

        // The previous version's helper must not serve the new commands (FR-019).
        _ = run("/bin/launchctl", ["kickstart", "-k", "gui/\(getuid())/com.kenscott.get-clear.helper"])
    }

    private static func isGenuine(_ app: URL) -> Bool {
        var code: SecStaticCode?
        var requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString(Self.requirement as CFString, [], &requirement) == errSecSuccess,
              let requirement
        else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        return SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess
    }

    private static func progress(_ line: String) {
        FileHandle.standardError.write(Data("\(line)\n".utf8))
    }

    private static func run(_ path: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return -1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }
}
