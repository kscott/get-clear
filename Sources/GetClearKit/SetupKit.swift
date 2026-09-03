// SetupKit.swift
//
// Shared primitives for interactive `setup` commands across the suite — the "prompt, read a
// line, match it, save" shape used by calendar, mail, and get-clear's own setup. Only the
// mechanical pieces are shared here; each tool's setup keeps its own domain logic (what's
// being configured, what format it's saved in, what happens after).

import Foundation

/// Prints `prompt` with no trailing newline, flushes stdout, and reads one line.
/// `readLine` is injectable for testing — defaults to the real `Swift.readLine()`.
public func promptLine(_ prompt: String, readLine: () -> String? = { Swift.readLine() }) -> String? {
    print(prompt, terminator: "")
    fflush(stdout)
    return readLine()
}

/// Strips non-printable characters (control codes, etc.) from raw terminal input and trims
/// surrounding whitespace.
public func sanitizeLine(_ s: String) -> String {
    String(s.unicodeScalars.filter { $0.value >= 32 && $0.value < 127 })
        .trimmingCharacters(in: .whitespaces)
}

/// Splits comma-separated freeform input into trimmed, non-empty tokens.
public func splitCommaTokens(_ input: String) -> [String] {
    input.components(separatedBy: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
}

/// Matches tokens against a numbered list (by position) or by name (case-insensitive, via
/// `titleOf`). Returns the titles that matched and the raw tokens that matched nothing.
/// Pure — no I/O.
public func matchNumberedTokens<T>(
    _ tokens: [String],
    numbered: [(number: Int, title: String)],
    items: [T],
    titleOf: (T) -> String
) -> (matched: [String], unmatched: [String]) {
    var matched: [String] = []
    var unmatched: [String] = []
    for token in tokens {
        if let num = Int(token), let entry = numbered.first(where: { $0.number == num }) {
            matched.append(entry.title)
        } else if let item = items.first(where: { titleOf($0).lowercased() == token.lowercased() }) {
            matched.append(titleOf(item))
        } else {
            unmatched.append(token)
        }
    }
    return (matched, unmatched)
}

/// Writes `content` to `configURL`, creating `configDir` if needed.
public func writeConfigFile(_ content: String, to configURL: URL, configDir: URL) throws {
    try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
    try content.write(to: configURL, atomically: true, encoding: .utf8)
}

/// Installs a SIGINT handler that prints "Cancelled." and exits — for commands that block on
/// user input, where Ctrl-C needs a clean message instead of a raw kill. Not unit tested: a
/// signal handler is process-global state, and calling exit() would kill the test run.
public func installCancelOnInterrupt() {
    signal(SIGINT) { _ in
        print("\nCancelled.")
        exit(0)
    }
}
