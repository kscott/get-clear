import Foundation

/// Configuration for the get-clear suite, read from ~/.config/get-clear/config.toml
public struct GetClearConfig {
    /// Calendar names to include in `get-clear recap`. nil = not configured.
    public let recapCalendars: [String]?

    public static let empty = GetClearConfig(recapCalendars: nil)

    public var isRecapConfigured: Bool { recapCalendars != nil }
}

/// Reads ~/.config/get-clear/config.toml and returns a GetClearConfig.
/// Returns .empty if the file doesn't exist or can't be parsed.
public func loadGetClearConfig() -> GetClearConfig {
    let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/get-clear/config.toml")
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        return .empty
    }
    return parseGetClearConfig(content)
}

public let getClearConfigURL: URL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/get-clear/config.toml")

func parseGetClearConfig(_ toml: String) -> GetClearConfig {
    var inRecap = false
    var recapCalendars: [String]? = nil

    for line in toml.components(separatedBy: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed == "[recap]" { inRecap = true; continue }
        if trimmed.hasPrefix("[") { inRecap = false; continue }
        guard inRecap else { continue }

        let parts = trimmed.components(separatedBy: "=")
        guard parts.count >= 2 else { continue }
        let key = parts[0].trimmingCharacters(in: .whitespaces)
        guard key == "calendars" else { continue }

        let value = parts[1...].joined(separator: "=")
        let names = value
            .components(separatedBy: "\"")
            .enumerated()
            .filter { $0.offset % 2 == 1 }
            .map { $0.element }
            .filter { !$0.isEmpty }
        if !names.isEmpty { recapCalendars = names }
    }

    return GetClearConfig(recapCalendars: recapCalendars)
}
