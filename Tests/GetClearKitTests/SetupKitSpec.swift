// SetupKitSpec.swift
//
// Tests for GetClearKit SetupKit — shared primitives for interactive setup commands.
// installCancelOnInterrupt is not tested: a signal handler is process-global, and its
// handler calls exit(), which would kill the test run.

import Foundation
import GetClearKit
import Testing

@Suite("promptLine")
struct PromptLineTests {
    @Test("returns the injected readLine's result")
    func returnsInjectedResult() {
        #expect(promptLine("Name: ", readLine: { "Work" }) == "Work")
    }

    @Test("returns nil when the injected readLine returns nil (EOF)")
    func returnsNilOnEOF() {
        #expect(promptLine("Name: ", readLine: { nil }) == nil)
    }
}

@Suite("sanitizeLine")
struct SanitizeLineTests {
    @Test("passes through plain text unchanged")
    func passesThroughPlainText() {
        #expect(sanitizeLine("Work") == "Work")
    }

    @Test("trims surrounding whitespace")
    func trimsWhitespace() {
        #expect(sanitizeLine("  Work  ") == "Work")
    }

    @Test("strips control characters")
    func stripsControlCharacters() {
        #expect(sanitizeLine("Wo\u{07}rk") == "Work")
    }
}

@Suite("splitCommaTokens")
struct SplitCommaTokensTests {
    @Test("splits a comma-separated list")
    func splitsCommaSeparatedList() {
        #expect(splitCommaTokens("Work, Personal, Home") == ["Work", "Personal", "Home"])
    }

    @Test("drops empty tokens from consecutive commas")
    func dropsEmptyTokens() {
        #expect(splitCommaTokens("Work,, Home") == ["Work", "Home"])
    }

    @Test("returns an empty array for empty input")
    func emptyForEmptyInput() {
        #expect(splitCommaTokens("").isEmpty)
    }

    @Test("returns an empty array for whitespace-only input")
    func emptyForWhitespaceOnlyInput() {
        #expect(splitCommaTokens("   ").isEmpty)
    }
}

@Suite("matchNumberedTokens")
struct MatchNumberedTokensTests {
    private struct Item { let title: String }
    private let numbered = [(number: 1, title: "Meetings"), (number: 2, title: "Work"), (number: 3, title: "Home")]
    private let items = [Item(title: "Meetings"), Item(title: "Work"), Item(title: "Home")]

    @Test("matches a token by its number")
    func matchesByNumber() {
        let (matched, _) = matchNumberedTokens(["1"], numbered: numbered, items: items, titleOf: \.title)
        #expect(matched == ["Meetings"])
    }

    @Test("matches a token by exact name, case-insensitively")
    func matchesByName() {
        let (matched, _) = matchNumberedTokens(["WORK"], numbered: numbered, items: items, titleOf: \.title)
        #expect(matched == ["Work"])
    }

    @Test("records a token that matches nothing as unmatched")
    func recordsUnmatched() {
        let (matched, unmatched) = matchNumberedTokens(["nope"], numbered: numbered, items: items, titleOf: \.title)
        #expect(matched.isEmpty)
        #expect(unmatched == ["nope"])
    }

    @Test("handles a mix of matched and unmatched tokens")
    func handlesMix() {
        let (matched, unmatched) = matchNumberedTokens(
            ["1", "work", "oops"], numbered: numbered, items: items, titleOf: \.title
        )
        #expect(matched == ["Meetings", "Work"])
        #expect(unmatched == ["oops"])
    }
}

@Suite("writeConfigFile")
struct WriteConfigFileTests {
    private func tempConfigURL() -> (configURL: URL, configDir: URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (dir.appendingPathComponent("config.toml"), dir)
    }

    @Test("creates the directory and writes the file")
    func createsDirectoryAndWritesFile() throws {
        let (configURL, configDir) = tempConfigURL()
        defer { try? FileManager.default.removeItem(at: configDir) }
        try writeConfigFile("[subsets]\n", to: configURL, configDir: configDir)
        #expect(FileManager.default.fileExists(atPath: configURL.path))
    }

    @Test("writes the exact content given")
    func writesExactContent() throws {
        let (configURL, configDir) = tempConfigURL()
        defer { try? FileManager.default.removeItem(at: configDir) }
        try writeConfigFile("[subsets]\nwork = [\"Work\"]\n", to: configURL, configDir: configDir)
        let content = try String(contentsOf: configURL, encoding: .utf8)
        #expect(content == "[subsets]\nwork = [\"Work\"]\n")
    }
}
