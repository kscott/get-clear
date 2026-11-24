// UpdatePlan.swift
//
// What `get-clear update` should do, decided from plain values (spec 018): nothing for a
// development build, nothing when already current, replace the app in place when it can, and
// fall back to the PKG + Installer flow when it can't. Pure; the command acts on the result.
//
// See specs/018-app-bundle-identity/contracts/cli-update.md.

import Foundation

/// The installed Get Clear.app, as the update decision needs it.
public struct InstalledApp: Equatable, Sendable {
    public let url: URL
    public let version: String
    /// Whether this user can replace the app: its folder and the app itself are writable.
    public let writable: Bool

    public init(url: URL, version: String, writable: Bool) {
        self.url = url
        self.version = version
        self.writable = writable
    }
}

public enum UpdatePlan: Equatable, Sendable {
    /// A development build, not running from an installed app.
    case notInstalledAsApp
    case upToDate(String)
    /// Download the app archive, verify it, and swap it in. No window, no password.
    case selfUpdate(from: String, to: String, asset: URL)
    /// Open the PKG in Installer, as before spec 018.
    case pkgFallback(from: String, to: String, asset: URL, reason: FallbackReason)

    public enum FallbackReason: Equatable, Sendable {
        /// The user can't write where the app is installed; Installer asks for a password.
        case notWritable(folder: URL)
        /// The release has no app archive (a release from before self-update existed).
        case noAppAsset
    }

    public static func decide(installed: InstalledApp?, latest: String, appAsset: URL?, pkgAsset: URL) -> UpdatePlan {
        guard let installed else { return .notInstalledAsApp }
        guard UpdateChecker.isNewer(latest, than: installed.version) else { return .upToDate(installed.version) }
        guard installed.writable else {
            return .pkgFallback(
                from: installed.version, to: latest, asset: pkgAsset,
                reason: .notWritable(folder: installed.url.deletingLastPathComponent())
            )
        }
        guard let appAsset else {
            return .pkgFallback(from: installed.version, to: latest, asset: pkgAsset, reason: .noAppAsset)
        }
        return .selfUpdate(from: installed.version, to: latest, asset: appAsset)
    }
}
