// HelperClient.swift
//
// The command side of the helper connection: a HelperTransport over NSXPCConnection that heals
// the two recoverable states before giving up (contract "Client behavior"): a helper that isn't
// registered is registered and retried once; a helper from another build is restarted and
// retried once.

import Darwin
import Foundation
import GetClearKit

public enum HelperClientError: LocalizedError, Equatable {
    case unavailable
    case needsApproval

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            "Get Clear's background helper isn't running. Reinstall Get Clear from the PKG."
        case .needsApproval:
            "Get Clear's background helper is turned off. Turn it on in System Settings → General → "
                + "Login Items & Extensions → Get Clear, then run the command again."
        }
    }
}

public enum HelperClient {
    /// The transport every remote store uses when the command runs from inside `appURL`.
    public static func transport(appURL: URL) -> HelperTransport {
        { envelope in try await send(envelope, appURL: appURL) }
    }

    static func send(_ envelope: HelperEnvelope, appURL: URL) async throws -> HelperReply {
        let data = try HelperCoding.encode(envelope)
        var reply: HelperReply
        do {
            reply = try await exchange(data)
        } catch {
            try register(appURL: appURL)
            do {
                reply = try await exchange(data)
            } catch {
                throw HelperClientError.unavailable
            }
        }
        if case .failure(.versionMismatch) = reply {
            kickstart()
            reply = await (try? exchange(data)) ?? reply
        }
        return reply
    }

    private static func exchange(_ data: Data) async throws -> HelperReply {
        let connection = NSXPCConnection(machServiceName: HelperXPC.machServiceName)
        connection.setCodeSigningRequirement(HelperXPC.peerRequirement)
        connection.remoteObjectInterface = NSXPCInterface(with: GetClearHelperXPC.self)
        connection.resume()
        defer { connection.invalidate() }
        let replyData: Data = try await withCheckedThrowingContinuation { continuation in
            let once = ResumeOnce(continuation)
            let proxy = connection.remoteObjectProxyWithErrorHandler { once.fail($0) } as? GetClearHelperXPC
            guard let proxy else {
                once.fail(HelperClientError.unavailable)
                return
            }
            proxy.perform(data) { once.succeed($0) }
        }
        return try HelperCoding.decode(HelperReply.self, from: replyData)
    }

    /// Runs `Get Clear register`. Exit 2 means the user has turned the background item off.
    private static func register(appURL: URL) throws {
        let status = run(appURL.appendingPathComponent("Contents/MacOS/Get Clear"), ["register"])
        switch status {
        case 0: return
        case 2: throw HelperClientError.needsApproval
        default: throw HelperClientError.unavailable
        }
    }

    /// Restarts the helper so the one launchd starts next is this build's (FR-019).
    private static func kickstart() {
        _ = run(URL(fileURLWithPath: "/bin/launchctl"), ["kickstart", "-k", "gui/\(getuid())/\(HelperXPC.machServiceName)"])
    }

    /// Runs a tool to completion with its output discarded, so a command's stdout stays clean.
    private static func run(_ executable: URL, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return -1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }
}

/// Resumes a continuation exactly once, whichever of the reply or the error handler fires first.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data, Error>?

    init(_ continuation: CheckedContinuation<Data, Error>) {
        self.continuation = continuation
    }

    func succeed(_ data: Data) {
        take()?.resume(returning: data)
    }

    func fail(_ error: Error) {
        take()?.resume(throwing: error)
    }

    private func take() -> CheckedContinuation<Data, Error>? {
        lock.lock()
        defer { lock.unlock() }
        let taken = continuation
        continuation = nil
        return taken
    }
}
