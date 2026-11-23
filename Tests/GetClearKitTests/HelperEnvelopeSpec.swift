// HelperEnvelopeSpec.swift
//
// Tests for GetClearKit HelperEnvelope — the command ↔ helper wire types.

import Foundation
import GetClearKit
import Testing

private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
    try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
}

private let envelope = HelperEnvelope(appVersion: "1.4.0", tool: .reminders, request: Data("{}".utf8))

@Suite("HelperEnvelope")
struct HelperEnvelopeTests {
    @Suite("coding")
    struct Coding {
        @Test("an envelope survives a JSON round trip")
        func envelopeRoundTrips() throws {
            #expect(try roundTrip(envelope) == envelope)
        }

        @Test("a success reply survives a JSON round trip")
        func successRoundTrips() throws {
            #expect(try roundTrip(HelperReply.success(Data("[1]".utf8))) == .success(Data("[1]".utf8)))
        }

        @Test("an access-denied failure keeps its permission")
        func accessDeniedRoundTrips() throws {
            #expect(try roundTrip(HelperReply.failure(.accessDenied(.contacts))) == .failure(.accessDenied(.contacts)))
        }

        @Test("a version-mismatch failure keeps the helper's versions")
        func versionMismatchRoundTrips() throws {
            let reply = HelperReply.failure(.versionMismatch(helperProtocol: 2, helperApp: "1.5.0"))
            #expect(try roundTrip(reply) == reply)
        }

        @Test("a tool-error failure keeps its payload")
        func toolErrorRoundTrips() throws {
            let reply = HelperReply.failure(.toolError(Data("{\"notFound\":{}}".utf8)))
            #expect(try roundTrip(reply) == reply)
        }

        @Test("a store-error failure keeps its exact message")
        func storeErrorRoundTrips() throws {
            let reply = HelperReply.failure(.storeError(message: "The operation couldn’t be completed. (EKErrorDomain error 1.)"))
            #expect(try roundTrip(reply) == reply)
        }

        @Test("a bad-request failure keeps its reason")
        func badRequestRoundTrips() throws {
            #expect(try roundTrip(HelperReply.failure(.badRequest("bad"))) == .failure(.badRequest("bad")))
        }

        @Test("a control request survives a JSON round trip")
        func controlRequestRoundTrips() throws {
            #expect(try roundTrip(HelperControlRequest.requestAccess(.messages)) == .requestAccess(.messages))
        }
    }

    @Suite("protocol version")
    struct ProtocolVersion {
        @Test("a new envelope carries the current protocol version")
        func defaultsToCurrent() {
            #expect(envelope.protocolVersion == HelperEnvelope.currentProtocolVersion)
        }
    }

    @Suite("versionFailure")
    struct VersionFailure {
        @Test("is nil when the protocol and app version both match")
        func matchingIsNil() {
            #expect(envelope.versionFailure(helperProtocol: HelperEnvelope.currentProtocolVersion, helperApp: "1.4.0") == nil)
        }

        @Test("reports the helper's versions when the app version differs")
        func appVersionDiffers() {
            let failure = envelope.versionFailure(helperProtocol: HelperEnvelope.currentProtocolVersion, helperApp: "1.3.9")
            #expect(failure == .versionMismatch(helperProtocol: HelperEnvelope.currentProtocolVersion, helperApp: "1.3.9"))
        }

        @Test("reports a mismatch when only the protocol version differs")
        func protocolDiffers() {
            #expect(envelope.versionFailure(helperProtocol: 99, helperApp: "1.4.0") == .versionMismatch(
                helperProtocol: 99,
                helperApp: "1.4.0"
            ))
        }
    }
}

@Suite("StoreKind")
struct StoreKindTests {
    @Test("covers exactly the four permissions Get Clear requests")
    func fourKinds() {
        #expect(StoreKind.allCases == [.reminders, .calendars, .contacts, .messages])
    }

    @Test("the Reminders denial points to the Reminders privacy pane and Get Clear")
    func remindersMessage() {
        #expect(StoreKind.reminders.deniedMessage
            == "Get Clear doesn't have access to Reminders. Turn it on in System Settings → Privacy & Security → Reminders → Get Clear.")
    }

    @Test("the Calendars denial points to the Calendars privacy pane")
    func calendarsMessage() {
        #expect(StoreKind.calendars.deniedMessage.contains("Privacy & Security → Calendars → Get Clear"))
    }

    @Test("the Contacts denial points to the Contacts privacy pane")
    func contactsMessage() {
        #expect(StoreKind.contacts.deniedMessage.contains("Privacy & Security → Contacts → Get Clear"))
    }

    @Test("the Messages denial points to Automation, under Get Clear")
    func messagesMessage() {
        #expect(StoreKind.messages.deniedMessage.contains("Privacy & Security → Automation → Get Clear → Messages"))
    }
}

@Suite("HelperTool.storeKind")
struct HelperToolStoreKindTests {
    @Test("reminders requests need Reminders access")
    func reminders() {
        #expect(HelperTool.reminders.storeKind == .reminders)
    }

    @Test("calendar requests need Calendars access")
    func calendar() {
        #expect(HelperTool.calendar.storeKind == .calendars)
    }

    @Test("contacts requests need Contacts access")
    func contacts() {
        #expect(HelperTool.contacts.storeKind == .contacts)
    }

    @Test("text requests need control of Messages")
    func text() {
        #expect(HelperTool.text.storeKind == .messages)
    }

    @Test("get-clear control requests need no permission of their own")
    func getClear() {
        #expect(HelperTool.getClear.storeKind == nil)
    }
}
