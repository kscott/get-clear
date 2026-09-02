// FindHandlerSpec.swift
// Tests for MailLib handleFind.

import Foundation
import MailLib
import Testing

@Suite("handleFind")
struct FindHandlerTests {
    @Suite("missing query")
    struct MissingQuery {
        @Test("throws when no search term is provided")
        func throwsWithoutSearchTerm() async {
            await #expect(throws: (any Error).self) {
                try await handleFind(args: ["find"], client: SpyMailClient())
            }
        }
    }

    @Suite("no results")
    struct NoResults {
        @Test("returns a not-found message")
        func returnsNotFoundMessage() async throws {
            let client = SpyMailClient()
            let result = try await handleFind(args: ["find", "quarterly"], client: client)
            #expect(result.contains("No messages matching"))
            #expect(result.contains("quarterly"))
        }
    }

    @Suite("with results")
    struct WithResults {
        @Test("returns one line per result")
        func oneLinePerResult() async throws {
            let client = SpyMailClient()
            client.findResults = [
                EmailSummary(subject: "Hello", from: "Alice <alice@example.com>", receivedAt: "2026-04-01T10:00:00Z"),
                EmailSummary(subject: "World", from: "Bob <bob@jones.org>", receivedAt: "2026-04-02T09:00:00Z")
            ]
            let result = try await handleFind(args: ["find", "query"], client: client)
            let lines = result.split(separator: "\n", omittingEmptySubsequences: false)
            #expect(lines.count == 2)
        }

        @Test("includes the subject in the output")
        func includesSubject() async throws {
            let client = SpyMailClient()
            client.findResults = [
                EmailSummary(subject: "Meeting notes", from: "Alice", receivedAt: "2026-04-01T10:00:00Z")
            ]
            let result = try await handleFind(args: ["find", "meeting"], client: client)
            #expect(result.contains("Meeting notes"))
        }

        @Test("joins multi-word query into a single search string")
        func joinsMultiWordQuery() async throws {
            let client = SpyMailClient()
            client.findResults = []
            let result = try await handleFind(args: ["find", "quarterly", "report"], client: client)
            #expect(result.contains("quarterly report"))
        }
    }

    @Suite("client throws")
    struct ClientThrows {
        @Test("propagates errors from the client")
        func propagatesClientErrors() async {
            let client = SpyMailClient()
            client.shouldThrow = MailError.jmapError("network error")
            await #expect(throws: (any Error).self) {
                try await handleFind(args: ["find", "query"], client: client)
            }
        }
    }
}
