// SendHandlerSpec.swift
// Tests for MailLib handleSend.

import Quick
import Nimble
import Foundation
import MailLib
import ContactKit
import ContactTestSupport

final class MailSendHandlerSpec: AsyncSpec {
    override class func spec() {

        describe("handleSend") {

            context("missing arguments") {
                it("throws when no recipient is provided") {
                    await expect {
                        try await handleSend(args: ["send"], config: testConfig,
                                             client: SpyMailClient(), contactStore: SpyContactStore())
                    }.to(throwError())
                }
                it("throws when args are empty") {
                    await expect {
                        try await handleSend(args: [], config: testConfig,
                                             client: SpyMailClient(), contactStore: SpyContactStore())
                    }.to(throwError())
                }
            }

            context("identity resolution") {
                it("throws when no identity matches the from address") {
                    let config = MailConfig(defaultFrom: "unknown@nowhere.com", identities: [testIdentity])
                    await expect {
                        try await handleSend(args: ["send", "alice@example.com", "subject", "Hi", "body", "Hello"],
                                             config: config, client: SpyMailClient(), contactStore: SpyContactStore())
                    }.to(throwError())
                }
            }

            context("sending to a raw email address") {
                it("calls send on the client") {
                    let client = SpyMailClient()
                    let store  = SpyContactStore()
                    _ = try await handleSend(args: ["send", "alice@example.com", "body", "Hello"],
                                             config: testConfig, client: client, contactStore: store)
                    expect(client.sentEmails.count) == 1
                }
                it("sets the to address correctly") {
                    let client = SpyMailClient()
                    _ = try await handleSend(args: ["send", "alice@example.com", "body", "Hello"],
                                             config: testConfig, client: client, contactStore: SpyContactStore())
                    expect(client.sentEmails.first?.to.first?.email) == "alice@example.com"
                }
                it("returns a confirmation containing the recipient") {
                    let client = SpyMailClient()
                    let result = try await handleSend(args: ["send", "alice@example.com", "body", "Hello"],
                                                      config: testConfig, client: client, contactStore: SpyContactStore())
                    expect(result).to(contain("alice@example.com"))
                }
            }

            context("sending with a subject") {
                it("includes the subject in the outbound email") {
                    let client = SpyMailClient()
                    _ = try await handleSend(args: ["send", "alice@example.com", "subject", "Lunch?", "body", "Free at noon"],
                                             config: testConfig, client: client, contactStore: SpyContactStore())
                    expect(client.sentEmails.first?.subject) == "Lunch?"
                }
                it("includes the subject in the output") {
                    let client = SpyMailClient()
                    let result = try await handleSend(args: ["send", "alice@example.com", "subject", "Lunch?", "body", "Free"],
                                                      config: testConfig, client: client, contactStore: SpyContactStore())
                    expect(result).to(contain("Lunch?"))
                }
            }

            context("draft flag") {
                it("calls saveDraft instead of send when --draft is present") {
                    let client = SpyMailClient()
                    _ = try await handleSend(args: ["send", "alice@example.com", "body", "Hello", "--draft"],
                                             config: testConfig, client: client, contactStore: SpyContactStore())
                    expect(client.savedDrafts.count) == 1
                    expect(client.sentEmails).to(beEmpty())
                }
                it("confirms draft was saved in the output") {
                    let client = SpyMailClient()
                    let result = try await handleSend(args: ["send", "alice@example.com", "body", "Hello", "--draft"],
                                                      config: testConfig, client: client, contactStore: SpyContactStore())
                    expect(result).to(contain("draft"))
                }
            }

            context("contact name resolution") {
                it("resolves a contact name to an email address") {
                    let client = SpyMailClient()
                    let store  = SpyContactStore()
                    store.contacts = [aliceContact]
                    _ = try await handleSend(args: ["send", "Alice", "body", "Hello"],
                                             config: testConfig, client: client, contactStore: store)
                    expect(client.sentEmails.first?.to.first?.email) == "alice@example.com"
                }
                it("includes the resolved display name in the output") {
                    let client = SpyMailClient()
                    let store  = SpyContactStore()
                    store.contacts = [aliceContact]
                    let result = try await handleSend(args: ["send", "Alice", "body", "Hello"],
                                                      config: testConfig, client: client, contactStore: store)
                    expect(result).to(contain("Alice Smith"))
                }
                it("throws when the contact cannot be resolved") {
                    await expect {
                        try await handleSend(args: ["send", "Nobody", "body", "Hello"],
                                             config: testConfig, client: SpyMailClient(), contactStore: SpyContactStore())
                    }.to(throwError())
                }
            }

            context("cc field") {
                it("resolves a cc recipient") {
                    let client = SpyMailClient()
                    let store  = SpyContactStore()
                    store.contacts = [aliceContact, bobContact]
                    _ = try await handleSend(
                        args: ["send", "alice@example.com", "cc", "bob@jones.org", "body", "Hi"],
                        config: testConfig, client: client, contactStore: store)
                    expect(client.sentEmails.first?.cc.first?.email) == "bob@jones.org"
                }
            }

            context("client throws") {
                it("propagates send errors") {
                    let client     = SpyMailClient()
                    client.shouldThrow = MailError.sendFailed("network error")
                    await expect {
                        try await handleSend(args: ["send", "alice@example.com", "body", "Hello"],
                                             config: testConfig, client: client, contactStore: SpyContactStore())
                    }.to(throwError())
                }
            }
        }

        describe("resolvedBody") {
            it("returns the string as-is when it is not a file path") {
                expect(resolvedBody("Hello world")) == "Hello world"
            }
            it("returns empty string unchanged") {
                expect(resolvedBody("")) == ""
            }
            it("reads body text from the file when the path exists") {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("mail-test-body.txt")
                try? "Hello from file".write(to: url, atomically: true, encoding: .utf8)
                expect(resolvedBody(url.path)) == "Hello from file"
                try? FileManager.default.removeItem(at: url)
            }
        }

        describe("loadGroupMembers") {
            it("returns an empty dict when there are no groups") {
                let store = SpyContactStore()
                let result = try await loadGroupMembers(from: store)
                expect(result).to(beEmpty())
            }
            it("maps group names to member AddressEntries") {
                let store = SpyContactStore()
                store.groups   = [ContactGroup(identifier: "g1", name: "Team")]
                store.contacts = [aliceContact]
                let result = try await loadGroupMembers(from: store)
                expect(result["Team"]?.first?.email) == "alice@example.com"
            }
            it("omits contacts with no email from group members") {
                let store = SpyContactStore()
                store.groups   = [ContactGroup(identifier: "g1", name: "Team")]
                store.contacts = [noEmailContact]
                let result = try await loadGroupMembers(from: store)
                expect(result).to(beEmpty())
            }
        }
    }
}
