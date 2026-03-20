import Darwin
import Foundation

/// Writes timestamped entries to the daily activity log.
/// Log location: `~/.local/share/get-clear/log/YYYY-MM-DD.log`
/// Append is atomic via POSIX O_APPEND — safe for concurrent processes.
public struct ActivityLog {

    static let defaultBaseDirectory: URL =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/get-clear/log")

    /// Writes one log entry for a successful write command.
    ///
    /// - Parameters:
    ///   - tool: One of: reminders, calendar, contacts, mail, sms
    ///   - cmd: The command executed: add, remove, change, rename, done, send
    ///   - desc: Human-readable description of the record acted on
    ///   - container: Scoping container (list name, calendar name, group name) or nil
    ///   - baseDirectory: Override for testing; defaults to `~/.local/share/get-clear/log`
    ///
    /// Callers MUST use `try? ActivityLog.write(...)` — log failure must never
    /// propagate to the calling command (FR-011, quickstart critical constraint).
    public static func write(
        tool: String,
        cmd: String,
        desc: String,
        container: String?,
        baseDirectory: URL? = nil
    ) throws {
        let base = baseDirectory ?? defaultBaseDirectory
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        let entry = ActivityLogEntry(ts: Date(), tool: tool, cmd: cmd, desc: desc, container: container)
        let data  = try JSONEncoder.logEncoder().encode(entry)
        guard var line = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        line += "\n"

        let today   = ISO8601DateFormatter.logFileDateString(Date())
        let fileURL = base.appendingPathComponent("\(today).log")
        let path    = fileURL.path

        // POSIX O_APPEND: kernel guarantees atomicity for small writes on macOS.
        // Do not use FileHandle.seekToEndOfFile() — seek and write are not atomic.
        let fd = open(path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
        guard fd >= 0 else { throw CocoaError(.fileWriteNoPermission) }
        defer { close(fd) }
        line.withCString { ptr in
            _ = Darwin.write(fd, ptr, strlen(ptr))
        }
    }
}
