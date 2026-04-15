// UpdateCommand.swift
// Downloads and installs the latest get-clear PKG release.

import Foundation
import GetClearKit

func runUpdate() {
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
}
