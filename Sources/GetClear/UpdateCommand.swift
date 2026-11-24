// UpdateCommand.swift
// Installs the latest Get Clear release: in place when it can, through the PKG when it can't.

import Foundation
import GetClearKit

func handleCheckUpdate(args: [String]) async throws {
    try validateNoArguments(args, shape: GetClearCommandShapes.checkUpdate)
    if let release = UpdateChecker.fetchLatestRelease(userAgent: "get-clear/\(builtVersion)") {
        UpdateChecker.writeCache(release)
    }
    exit(0)
}

func handleUpdate(args: [String]) async throws {
    try validateNoArguments(args, shape: GetClearCommandShapes.update)
    guard let app = UpdateChecker.installedApp() else {
        print("get-clear update is only available for PKG installs.")
        print("Download from https://github.com/kscott/get-clear/releases")
        exit(0)
    }

    let latest: LatestRelease
    if let cached = UpdateChecker.cachedLatest(), Date().timeIntervalSince(cached.checked) < 3600 {
        latest = cached.release
    } else {
        print("Checking for latest version...")
        guard let fresh = UpdateChecker.fetchLatestRelease(userAgent: "get-clear/\(builtVersion)") else {
            throw GetClearError("Could not reach GitHub. Check your connection and try again.")
        }
        UpdateChecker.writeCache(fresh)
        latest = fresh
    }
    guard let pkgURL = URL(string: latest.pkgURL) else {
        throw GetClearError("Malformed download URL from GitHub: \(latest.pkgURL)")
    }

    switch UpdatePlan.decide(installed: app, latest: latest.version, appAsset: latest.appURL.flatMap(URL.init(string:)), pkgAsset: pkgURL) {
    case .notInstalledAsApp:
        return // unreachable: installedApp() was non-nil
    case let .upToDate(version):
        print("Already on the latest version (\(version)).")
    case let .selfUpdate(_, to, asset):
        try await SelfUpdater.install(over: app, version: to, from: asset)
        print("Get Clear updated to \(to).")
    case let .pkgFallback(from, to, asset, reason):
        if case let .notWritable(folder) = reason {
            FileHandle.standardError.write(Data((
                "Get Clear can't replace itself in \(folder.path) — opening the installer instead. "
                    + "A password will be required.\n"
            ).utf8))
        }
        try await installViaPKG(from: from, to: to, asset: asset)
    }
    exit(0)
}

/// The pre-spec-018 flow: download the PKG and open it in Installer.
private func installViaPKG(from installed: String, to latestVersion: String, asset: URL) async throws {
    print("Updating get-clear \(installed) → \(latestVersion)...")
    print("Downloading get-clear \(latestVersion)...")
    let tempPkg = URL(fileURLWithPath: "/tmp/get-clear-\(latestVersion).pkg")
    do {
        let (data, _) = try await URLSession.shared.data(from: asset)
        try data.write(to: tempPkg, options: .atomic)
    } catch {
        try? FileManager.default.removeItem(at: tempPkg)
        throw GetClearError("Download failed: \(error.localizedDescription)")
    }
    print("Download complete.")
    print("A password will be required to complete installation.")
    let opener = Process()
    opener.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    opener.arguments = [tempPkg.path]
    try? opener.run()
}
