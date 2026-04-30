// FindHandlerSpec.swift
// Tests for MailLib handleFind.

import Quick
import Nimble
import Foundation
import MailLib

final class MailFindHandlerSpec: AsyncSpec {
    override class func spec() {

        describe("handleFind") {

            context("missing query") {
                it("throws when no search term is provided") {
                    await expect {
                        try await handleFind(args: ["find"], client: SpyMailClient())
                    }.to(throwError())
                }
            }

            context("no results") {
                it("returns a not-found message") {
                    let client = SpyMailClient()
                    let result = try await handleFind(args: ["find", "quarterly"], client: client)
                    expect(result).to(contain("No messages matching"))
                    expect(result).to(contain("quarterly"))
                }
            }

            context("with results") {
                it("returns one line per result") {
                    let client = SpyMailClient()
                    client.findResults = [
                        EmailSummary(subject: "Hello", from: "Alice <alice@example.com>", receivedAt: "2026-04-01T10:00:00Z"),
                        EmailSummary(subject: "World", from: "Bob <bob@jones.org>",       receivedAt: "2026-04-02T09:00:00Z"),
                    ]
                    let result = try await handleFind(args: ["find", "query"], client: client)
                    let lines  = result.split(separator: "\n", omittingEmptySubsequences: false)
                    expect(lines.count) == 2
                }
                it("includes the subject in the output") {
                    let client = SpyMailClient()
                    client.findResults = [
                        EmailSummary(subject: "Meeting notes", from: "Alice", receivedAt: "2026-04-01T10:00:00Z"),
                    ]
                    let result = try await handleFind(args: ["find", "meeting"], client: client)
                    expect(result).to(contain("Meeting notes"))
                }
                it("joins multi-word query into a single search string") {
                    let client = SpyMailClient()
                    client.findResults = []
                    let result = try await handleFind(args: ["find", "quarterly", "report"], client: client)
                    expect(result).to(contain("quarterly report"))
                }
            }

            context("client throws") {
                it("propagates errors from the client") {
                    let client = SpyMailClient()
                    client.shouldThrow = MailError.jmapError("network error")
                    await expect {
                        try await handleFind(args: ["find", "query"], client: client)
                    }.to(throwError())
                }
            }
        }
    }
}
