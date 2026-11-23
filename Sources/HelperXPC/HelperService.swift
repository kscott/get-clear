// HelperService.swift
//
// The helper side of the connection: an NSXPCListener on the helper's Mach service that accepts
// only Get Clear's own signed commands (C1), hands each envelope to a HelperGate, serves
// connections concurrently (C5), and exits after a quiet period with no connections (C6).

import Foundation
import GetClearKit

public final class HelperService: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private let gate: HelperGate
    private let listener = NSXPCListener(machServiceName: HelperXPC.machServiceName)
    private let idle: IdleExit

    public init(gate: HelperGate, idleTimeout: TimeInterval = 60) {
        self.gate = gate
        idle = IdleExit(timeout: idleTimeout)
    }

    /// Serves requests until the helper has been idle for the timeout, then exits the process.
    public func run() -> Never {
        listener.delegate = self
        listener.resume()
        idle.start()
        dispatchMain()
    }

    public func listener(_: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.setCodeSigningRequirement(HelperXPC.peerRequirement)
        connection.exportedInterface = NSXPCInterface(with: GetClearHelperXPC.self)
        connection.exportedObject = Exported(gate: gate)
        idle.opened()
        connection.invalidationHandler = { [idle] in idle.closed() }
        connection.resume()
        return true
    }
}

private final class Exported: NSObject, GetClearHelperXPC, @unchecked Sendable {
    private let gate: HelperGate

    init(gate: HelperGate) {
        self.gate = gate
    }

    func perform(_ envelope: Data, reply: @escaping (Data) -> Void) {
        Task { [gate] in
            let answer = await gate.reply(to: envelope)
            reply((try? HelperCoding.encode(answer)) ?? Data())
        }
    }
}

/// Counts open connections and exits the process once none has been open for `timeout`.
private final class IdleExit: @unchecked Sendable {
    private let timeout: TimeInterval
    private let queue = DispatchQueue(label: "com.kenscott.get-clear.helper.idle")
    private var open = 0
    private var pending: DispatchWorkItem?

    init(timeout: TimeInterval) {
        self.timeout = timeout
    }

    func start() {
        queue.async { self.scheduleIfIdle() }
    }

    func opened() {
        queue.async {
            self.open += 1
            self.pending?.cancel()
            self.pending = nil
        }
    }

    func closed() {
        queue.async {
            self.open = max(0, self.open - 1)
            self.scheduleIfIdle()
        }
    }

    private func scheduleIfIdle() {
        guard open == 0 else { return }
        pending?.cancel()
        let work = DispatchWorkItem { exit(0) }
        pending = work
        queue.asyncAfter(deadline: .now() + timeout, execute: work)
    }
}
