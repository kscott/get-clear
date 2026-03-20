import Foundation

/// A single recorded action written to the daily log file.
/// Serialized as one JSON object per line (JSON Lines format).
public struct ActivityLogEntry: Codable {
    public let ts: Date
    public let tool: String
    public let cmd: String
    public let desc: String
    public let container: String?

    public init(ts: Date, tool: String, cmd: String, desc: String, container: String?) {
        self.ts        = ts
        self.tool      = tool
        self.cmd       = cmd
        self.desc      = desc
        self.container = container
    }

    // Custom encode: always write "container":null rather than omitting the key.
    // Swift's synthesized Codable uses encodeIfPresent for optionals, which omits nil keys.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ts,   forKey: .ts)
        try c.encode(tool, forKey: .tool)
        try c.encode(cmd,  forKey: .cmd)
        try c.encode(desc, forKey: .desc)
        if let container = container {
            try c.encode(container, forKey: .container)
        } else {
            try c.encodeNil(forKey: .container)
        }
    }
}

// MARK: - Shared JSON helpers

extension JSONDecoder {
    /// Returns a decoder configured for activity log entries (ISO 8601 dates).
    public static func logDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

extension JSONEncoder {
    /// Returns an encoder configured for activity log entries (ISO 8601 dates).
    static func logEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

// MARK: - Shared date helpers

extension ISO8601DateFormatter {
    /// Returns the "yyyy-MM-dd" string for the local calendar date of the given date.
    /// Used for log file naming: `~/.local/share/get-clear/log/YYYY-MM-DD.log`
    public static func logFileDateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
}
