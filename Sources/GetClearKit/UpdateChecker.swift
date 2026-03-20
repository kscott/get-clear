// UpdateChecker.swift
//
// Checks for new versions of Get Clear and surfaces a hint to the user.
// Only active on PKG installs — dev machines (no pkgutil receipt) are skipped silently.
//
// Flow:
//   1. On each tool invocation, spawnBackgroundCheckIfNeeded() fires get-clear check-update
//      as a detached process if the cache is older than 1 hour.
//   2. hint() reads the cache and returns a formatted stderr line if a newer version is available.
//   3. get-clear check-update hits the GitHub API and writes the cache.
//   4. get-clear update downloads the PKG and opens it in Installer.app.

import Darwin
import Foundation

public enum UpdateChecker {

    static let cacheURL: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".local/share/get-clear/update-check.json")

    static let checkInterval: TimeInterval = 3600 // 1 hour

    // MARK: - Public API

    /// Returns the installed version string from pkgutil, or nil if not installed via PKG.
    public static func installedVersion() -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/pkgutil")
        p.arguments = ["--pkg-info", "com.kenscott.get-clear"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("version:") {
                return trimmed.dropFirst("version:".count).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// Returns cached latest version info, or nil if no cache exists or it is malformed.
    public static func cachedLatest() -> (version: String, url: String, checked: Date)? {
        guard let data = try? Data(contentsOf: cacheURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let version = json["version"],
              let url     = json["url"],
              let checked = json["checked"].flatMap({ ISO8601DateFormatter().date(from: $0) })
        else { return nil }
        return (version, url, checked)
    }

    /// Returns a hint string for stderr if a newer version is available, otherwise nil.
    public static func hint() -> String? {
        guard let installed = installedVersion() else { return nil }
        guard let (latest, _, _) = cachedLatest() else { return nil }
        guard isNewer(latest, than: installed) else { return nil }
        let changelogURL = "https://github.com/kscott/get-clear/releases/tag/v\(latest)"
        let text = "get-clear \(latest) available — run: get-clear update  (what's new: \(changelogURL))"
        return "⭐ \(ANSI.dim(text))"
    }

    /// Spawns `get-clear check-update` as a detached background process if the cache is stale.
    /// No-op if not installed via PKG. Returns immediately.
    public static func spawnBackgroundCheckIfNeeded() {
        guard installedVersion() != nil else { return }
        if let (_, _, checked) = cachedLatest(),
           Date().timeIntervalSince(checked) < checkInterval { return }

        // Find the get-clear binary — PKG installs to /usr/local/bin
        let binaryPath = "/usr/local/bin/get-clear"
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else { return }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: binaryPath)
        p.arguments = ["check-update"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError  = FileHandle.nullDevice
        do {
            try p.run()
            // Create a new process group so the child outlives the parent
            setpgid(p.processIdentifier, 0)
        } catch {
            // Silent failure — background check is best-effort
        }
    }

    // MARK: - Internal

    /// Writes the latest version info to the cache file.
    /// Called by the `check-update` subcommand after a successful API fetch.
    public static func writeCache(version: String, url: String) {
        let json: [String: String] = [
            "version": version,
            "url":     url,
            "checked": ISO8601DateFormatter().string(from: Date())
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return }
        let dir = cacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: .atomic)
    }

    /// Returns true if `a` is a higher semver than `b`.
    public static func isNewer(_ a: String, than b: String) -> Bool {
        let av = components(of: a)
        let bv = components(of: b)
        for i in 0..<3 {
            let ai = i < av.count ? av[i] : 0
            let bi = i < bv.count ? bv[i] : 0
            if ai != bi { return ai > bi }
        }
        return false
    }

    private static func components(of version: String) -> [Int] {
        version.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
               .components(separatedBy: ".")
               .compactMap(Int.init)
    }
}
