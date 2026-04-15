// VersionString.swift
// Formats the version display string for any Get Clear tool.

/// Returns the formatted version string for display.
///
/// When `built` matches `suite`, returns `"tool built"` (e.g. `"get-clear 1.3.0"`).
/// When they differ, appends the suite version in parentheses
/// (e.g. `"reminders 1.2.0 (Get Clear 1.3.0)"`).
public func versionString(tool: String, built: String, suite: String) -> String {
    if built == suite {
        return "\(tool) \(built)"
    }
    return "\(tool) \(built) (Get Clear \(suite))"
}
