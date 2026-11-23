// AccessRoute.swift
//
// Decides how a command reaches Reminders, Calendars, Contacts, and Messages: through the
// Get Clear app's helper when the command runs from inside the installed app, or directly
// when it doesn't (a development build). Pure path logic; the caller resolves symlinks.
//
// See specs/018-app-bundle-identity/research.md R10.

import Foundation

public enum AccessRoute: Equatable, Sendable {
    /// The command lives in `<appURL>/Contents/Helpers/`; store access goes through the app's helper.
    case helper(appURL: URL)
    /// Anything else; the command accesses the stores in-process, as before spec 018.
    case direct

    /// The installed app's bundle name. A renamed copy is not the installed app.
    public static let appBundleName = "Get Clear.app"

    /// - Parameter resolvedExecutable: the running command's path with symlinks resolved, so
    ///   `/usr/local/bin/reminders` arrives as the path inside the app.
    public static func decide(resolvedExecutable: URL) -> AccessRoute {
        let helpersDir = resolvedExecutable.deletingLastPathComponent()
        let contentsDir = helpersDir.deletingLastPathComponent()
        let appURL = contentsDir.deletingLastPathComponent()
        guard helpersDir.lastPathComponent == "Helpers",
              contentsDir.lastPathComponent == "Contents",
              appURL.lastPathComponent == appBundleName
        else {
            return .direct
        }
        // Normalized as a directory URL so equality never depends on a trailing slash.
        return .helper(appURL: URL(fileURLWithPath: appURL.path, isDirectory: true))
    }
}
