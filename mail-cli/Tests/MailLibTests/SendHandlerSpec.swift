// SendHandlerSpec.swift
// Tests for MailLib handleSend and handleDraft.

import ContactKit
import ContactTestSupport
import Foundation
import MailLib
import Testing

@Suite("handleSend")
struct SendHandlerTests {
    @Suite("missing arguments")
    struct MissingArguments {
        @Test("throws when no recipient is provided")
        func throwsWithoutRecipient() async {
            await #expect(throws: (any Error).self) {
                try await handleSend(args: ["send"], config: testConfig,
                                     client: SpyMailClient(), contactStore: SpyContactStore())
            }
        }

        @Test("throws when args are empty")
        func throwsWhenArgsEmpty() async {
            await #expect(throws: (any Error).self) {
                try await handleSend(args: [], config: testConfig,
                                     client: SpyMailClient(), contactStore: SpyContactStore())
            }
        }
    }

    @Suite("identity resolution")
    struct IdentityResolution {
        @Test("throws when no identity matches the from address")
        func throwsWhenNoIdentityMatches() async {
            let config = MailConfig(defaultFrom: "unknown@nowhere.com", identities: [testIdentity])
            await #expect(throws: (any Error).self) {
                try await handleSend(args: ["send", "alice@example.com", "subject", "Hi", "body", "Hello"],
                                     config: config, client: SpyMailClient(), contactStore: SpyContactStore())
            }
        }
    }

    @Suite("sending to a raw email address")
    struct SendingToRawEmail {
        @Test("calls send on the client")
        func callsSendOnClient() async throws {
            let client = SpyMailClient()
            let store = SpyContactStore()
            _ = try await handleSend(args: ["send", "alice@example.com", "body", "Hello"],
                                     config: testConfig, client: client, contactStore: store)
            #expect(client.sentEmails.count == 1)
        }

        @Test("sets the to address correctly")
        func setsToAddress() async throws {
            let client = SpyMailClient()
            _ = try await handleSend(args: ["send", "alice@example.com", "body", "Hello"],
                                     config: testConfig, client: client, contactStore: SpyContactStore())
            #expect(client.sentEmails.first?.to.first?.email == "alice@example.com")
        }

        @Test("returns a confirmation containing the recipient")
        func confirmationContainsRecipient() async throws {
            let client = SpyMailClient()
            let result = try await handleSend(args: ["send", "alice@example.com", "body", "Hello"],
                                              config: testConfig, client: client, contactStore: SpyContactStore())
            #expect(result.contains("alice@example.com"))
        }
    }

    @Suite("sending with a subject")
    struct SendingWithSubject {
        @Test("includes the subject in the outbound email")
        func includesSubjectInOutbound() async throws {
            let client = SpyMailClient()
            _ = try await handleSend(args: ["send", "alice@example.com", "subject", "Lunch?", "body", "Free at noon"],
                                     config: testConfig, client: client, contactStore: SpyContactStore())
            #expect(client.sentEmails.first?.subject == "Lunch?")
        }

        @Test("includes the subject in the output")
        func includesSubjectInOutput() async throws {
            let client = SpyMailClient()
            let result = try await handleSend(args: ["send", "alice@example.com", "subject", "Lunch?", "body", "Free"],
                                              config: testConfig, client: client, contactStore: SpyContactStore())
            #expect(result.contains("Lunch?"))
        }
    }

    @Suite("contact name resolution")
    struct ContactNameResolution {
        @Test("resolves a contact name to an email address")
        func resolvesContactNameToEmail() async throws {
            let client = SpyMailClient()
            let store = SpyContactStore()
            store.contacts = [aliceContact]
            _ = try await handleSend(args: ["send", "Alice", "body", "Hello"],
                                     config: testConfig, client: client, contactStore: store)
            #expect(client.sentEmails.first?.to.first?.email == "alice@example.com")
        }

        @Test("includes the resolved display name in the output")
        func includesResolvedDisplayName() async throws {
            let client = SpyMailClient()
            let store = SpyContactStore()
            store.contacts = [aliceContact]
            let result = try await handleSend(args: ["send", "Alice", "body", "Hello"],
                                              config: testConfig, client: client, contactStore: store)
            #expect(result.contains("Alice Smith"))
        }

        @Test("throws when the contact cannot be resolved")
        func throwsWhenContactUnresolved() async {
            await #expect(throws: (any Error).self) {
                try await handleSend(args: ["send", "Nobody", "body", "Hello"],
                                     config: testConfig, client: SpyMailClient(), contactStore: SpyContactStore())
            }
        }
    }

    @Suite("cc field")
    struct CcField {
        @Test("resolves a cc recipient")
        func resolvesCcRecipient() async throws {
            let client = SpyMailClient()
            let store = SpyContactStore()
            store.contacts = [aliceContact, bobContact]
            _ = try await handleSend(
                args: ["send", "alice@example.com", "cc", "bob@jones.org", "body", "Hi"],
                config: testConfig, client: client, contactStore: store
            )
            #expect(client.sentEmails.first?.cc.first?.email == "bob@jones.org")
        }

        @Test("resolves multiple cc recipients from repeated keyword")
        func resolvesMultipleCcRecipients() async throws {
            let client = SpyMailClient()
            let store = SpyContactStore()
            store.contacts = [aliceContact, bobContact]
            _ = try await handleSend(
                args: ["send", "alice@example.com", "cc", "bob@jones.org", "cc", "carol@example.com", "body", "Hi"],
                config: testConfig, client: client, contactStore: store
            )
            #expect(client.sentEmails.first?.cc.map(\.email) == ["bob@jones.org", "carol@example.com"])
        }
    }

    @Suite("attach field")
    struct AttachField {
        @Test("attaches multiple files from repeated keyword")
        func attachesMultipleFiles() async throws {
            let client = SpyMailClient()
            _ = try await handleSend(
                args: ["send", "alice@example.com", "attach", "/tmp/a.pdf", "attach", "/tmp/b.pdf", "body", "Hi"],
                config: testConfig, client: client, contactStore: SpyContactStore()
            )
            #expect(client.sentEmails.first?.attachmentPaths == ["/tmp/a.pdf", "/tmp/b.pdf"])
        }
    }

    @Suite("client throws")
    struct ClientThrows {
        @Test("propagates send errors")
        func propagatesSendErrors() async {
            let client = SpyMailClient()
            client.shouldThrow = MailError.sendFailed("network error")
            await #expect(throws: (any Error).self) {
                try await handleSend(args: ["send", "alice@example.com", "body", "Hello"],
                                     config: testConfig, client: client, contactStore: SpyContactStore())
            }
        }
    }
}

@Suite("handleDraft")
struct DraftHandlerTests {
    @Test("calls saveDraft instead of send")
    func callsSaveDraft() async throws {
        let client = SpyMailClient()
        _ = try await handleDraft(args: ["draft", "alice@example.com", "body", "Hello"],
                                  config: testConfig, client: client, contactStore: SpyContactStore())
        #expect(client.savedDrafts.count == 1)
        #expect(client.sentEmails.isEmpty)
    }

    @Test("confirms draft was saved in the output")
    func confirmsDraftSaved() async throws {
        let client = SpyMailClient()
        let result = try await handleDraft(args: ["draft", "alice@example.com", "body", "Hello"],
                                           config: testConfig, client: client, contactStore: SpyContactStore())
        #expect(result.contains("draft"))
    }

    @Test("throws when no body is provided, same as send")
    func throwsWhenNoBody() async {
        await #expect(throws: (any Error).self) {
            try await handleDraft(args: ["draft", "alice@example.com"], config: testConfig,
                                  client: SpyMailClient(), contactStore: SpyContactStore())
        }
    }
}

@Suite("body content")
struct BodyContentTests {
    @Suite("body with special characters")
    struct BodyWithSpecialCharacters {
        @Test("delivers apostrophes and contractions to the client exactly as-is")
        func deliversApostrophes() async throws {
            let client = SpyMailClient()
            let body = "I wanted you to see it first so you're not caught off guard, and so you're ready if people reach out."
            _ = try await handleSend(args: ["send", "alice@example.com", "body", body],
                                     config: testConfig, client: client, contactStore: SpyContactStore())
            #expect(client.sentEmails.first?.body == body)
        }

        @Test("delivers newlines to the client exactly as-is")
        func deliversNewlines() async throws {
            let client = SpyMailClient()
            let body = "Line one.\n\nLine two.\n\nLine three."
            _ = try await handleSend(args: ["send", "alice@example.com", "body", body],
                                     config: testConfig, client: client, contactStore: SpyContactStore())
            #expect(client.sentEmails.first?.body == body)
        }

        @Test("delivers em-dashes and asterisks to the client exactly as-is")
        func deliversEmDashesAndAsterisks() async throws {
            let client = SpyMailClient()
            let body = "Join us — I can forward details to anyone who's interested.\n*Nursery available all morning."
            _ = try await handleSend(args: ["send", "alice@example.com", "body", body],
                                     config: testConfig, client: client, contactStore: SpyContactStore())
            #expect(client.sentEmails.first?.body == body)
        }
    }

    @Suite("empty body")
    struct EmptyBody {
        @Test("throws when body is an empty string")
        func throwsWhenBodyEmptyString() async {
            await #expect(throws: (any Error).self) {
                try await handleSend(args: ["send", "alice@example.com", "body", ""],
                                     config: testConfig, client: SpyMailClient(), contactStore: SpyContactStore())
            }
        }

        @Test("throws when no body is provided")
        func throwsWhenNoBody() async {
            await #expect(throws: (any Error).self) {
                try await handleSend(args: ["send", "alice@example.com", "subject", "Hi"],
                                     config: testConfig, client: SpyMailClient(), contactStore: SpyContactStore())
            }
        }
    }
}

@Suite("loadGroupMembers")
struct LoadGroupMembersTests {
    @Test("returns an empty dict when there are no groups")
    func emptyDictWhenNoGroups() async throws {
        let store = SpyContactStore()
        let result = try await loadGroupMembers(from: store)
        #expect(result.isEmpty)
    }

    @Test("maps group names to member AddressEntries")
    func mapsGroupNamesToMembers() async throws {
        let store = SpyContactStore()
        store.groups = [ContactGroup(identifier: "g1", name: "Team")]
        store.contacts = [aliceContact]
        let result = try await loadGroupMembers(from: store)
        #expect(result["Team"]?.first?.email == "alice@example.com")
    }

    @Test("omits contacts with no email from group members")
    func omitsContactsWithNoEmail() async throws {
        let store = SpyContactStore()
        store.groups = [ContactGroup(identifier: "g1", name: "Team")]
        store.contacts = [noEmailContact]
        let result = try await loadGroupMembers(from: store)
        #expect(result.isEmpty)
    }
}
