// UpdateChecker.swift
//
// Checks for new versions of Get Clear and surfaces a hint to the user.
// Only active when running from the installed Get Clear.app — development builds are skipped.
//
// Flow:
//   1. On each tool invocation, spawnBackgroundCheckIfNeeded() fires get-clear check-update
//      as a detached process if the cache is older than 1 hour.
//   2. hint() reads the cache and returns a formatted stderr line if a newer version is available.
//   3. get-clear check-update hits the GitHub API and writes the cache.
//   4. get-clear update replaces the app in place, or falls back to the PKG (UpdatePlan).
//
// The installed version is the app's own CFBundleShortVersionString, not the PKG receipt: after
// a self-update the receipt still names the old version (spec 018 R9).

import Darwin
import Foundation

/// The newest release on GitHub and its two installable assets.
public struct LatestRelease: Equatable, Sendable {
    public let version: String
    /// get-clear.pkg: first install, fallback, and what 1.3.x's updater downloads.
    public let pkgURL: String
    /// Get-Clear.zip: the notarized app, for self-update. Nil for releases from before spec 018.
    public let appURL: String?

    public init(version: String, pkgURL: String, appURL: String?) {
        self.version = version
        self.pkgURL = pkgURL
        self.appURL = appURL
    }
}

public enum UpdateChecker {
    // MARK: - Constants

    static let binaryPath = "/usr/local/bin/get-clear"
    static let releasesAPIURL = "https://api.github.com/repos/kscott/get-clear/releases/latest"
    static let releasesTagURL = "https://github.com/kscott/get-clear/releases/tag/v"

    static let cacheURL: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".local/share/get-clear/update-check.json")

    static let checkInterval: TimeInterval = 3600 // 1 hour

    private static let iso8601 = ISO8601DateFormatter()

    // MARK: - Public API

    /// The installed app this command is running from, or nil for a development build.
    public static func installedApp() -> InstalledApp? {
        guard case let .helper(appURL) = AccessRoute.current,
              let info = NSDictionary(contentsOf: appURL.appendingPathComponent("Contents/Info.plist")) as? [String: Any],
              let version = appVersion(fromInfo: info)
        else { return nil }
        let fm = FileManager.default
        let writable = fm.isWritableFile(atPath: appURL.deletingLastPathComponent().path)
            && fm.isWritableFile(atPath: appURL.path)
        return InstalledApp(url: appURL, version: version, writable: writable)
    }

    /// The installed version, or nil for a development build.
    public static func installedVersion() -> String? {
        installedApp()?.version
    }

    /// An app's version from its Info.plist contents.
    public static func appVersion(fromInfo info: [String: Any]) -> String? {
        info["CFBundleShortVersionString"] as? String
    }

    /// Returns cached latest release info, or nil if no cache exists or it is malformed.
    public static func cachedLatest() -> (release: LatestRelease, checked: Date)? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return parseCache(data)
    }

    /// Reads the cache file's contents. The `url` key is the PKG, as 1.3.x writes and reads it;
    /// `appURL` is added alongside, so old and new versions can share one cache file.
    public static func parseCache(_ data: Data) -> (release: LatestRelease, checked: Date)? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let version = json["version"],
              let url = json["url"],
              let checked = json["checked"].flatMap({ iso8601.date(from: $0) })
        else { return nil }
        return (LatestRelease(version: version, pkgURL: url, appURL: json["appURL"]), checked)
    }

    /// Reads a GitHub "latest release" API response. Nil when it isn't a versioned release with a PKG.
    public static func parseLatestRelease(_ data: Data) -> LatestRelease? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let assets = json["assets"] as? [[String: Any]]
        else { return nil }
        func assetURL(_ name: String) -> String? {
            assets.first { ($0["name"] as? String) == name }?["browser_download_url"] as? String
        }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard version != "latest", let pkg = assetURL("get-clear.pkg") else { return nil } // rolling tag has no semver
        return LatestRelease(version: version, pkgURL: pkg, appURL: assetURL("Get-Clear.zip"))
    }

    /// Fetches the latest release from GitHub, or nil on failure.
    /// Synchronous — call only from a background context or the check-update subcommand.
    public static func fetchLatestRelease(userAgent: String) -> LatestRelease? {
        guard let apiURL = URL(string: releasesAPIURL) else { return nil }
        var request = URLRequest(url: apiURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        nonisolated(unsafe) var result: LatestRelease?
        let sem = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, _, _ in
            defer { sem.signal() }
            result = data.flatMap(parseLatestRelease)
        }.resume()
        sem.wait()
        return result
    }

    /// Returns a hint string for stderr if a newer version is available, otherwise nil.
    public static func hint() -> String? {
        guard let installed = installedVersion() else { return nil }
        guard let (latest, _) = cachedLatest() else { return nil }
        guard isNewer(latest.version, than: installed) else { return nil }
        let text = "get-clear \(latest.version) available — run: get-clear update  (what's new: \(releasesTagURL)\(latest.version))"
        return "⭐ \(ANSI.dim(text))"
    }

    /// Spawns `get-clear check-update` as a detached background process if the cache is stale.
    /// No-op for a development build. Returns immediately.
    public static func spawnBackgroundCheckIfNeeded() {
        guard installedVersion() != nil else { return }
        if let (_, checked) = cachedLatest(),
           Date().timeIntervalSince(checked) < checkInterval { return }
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: binaryPath)
        p.arguments = ["check-update"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            // Create a new process group so the child outlives the parent
            setpgid(p.processIdentifier, 0)
        } catch {
            // Silent failure — background check is best-effort
        }
    }

    // MARK: - Internal

    /// Writes the latest release info to the cache file.
    /// Called by the `check-update` subcommand after a successful API fetch.
    public static func writeCache(_ release: LatestRelease) {
        var json: [String: String] = [
            "version": release.version,
            "url": release.pkgURL,
            "checked": iso8601.string(from: Date())
        ]
        json["appURL"] = release.appURL
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return }
        let dir = cacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: .atomic)
    }

    /// Returns true if `a` is a higher semver than `b`.
    /// Assumes standard X.Y.Z format — pre-release suffixes are not supported.
    public static func isNewer(_ a: String, than b: String) -> Bool {
        let av = components(of: a)
        let bv = components(of: b)
        for i in 0 ..< 3 {
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
