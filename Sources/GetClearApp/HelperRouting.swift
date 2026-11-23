// HelperRouting.swift
//
// Builds the helper's gate: which permissions each envelope needs, and which tool's dispatch
// runs it against the real Apple stores. Each store is created per request, after the gate has
// secured access, so a grant made mid-session is seen immediately.

import AppleContactKit
import CalendarEventKit
import CalendarLib
import ContactKit
import Contacts
import EventKit
import Foundation
import GetClearKit
import RemindersEventKit
import RemindersLib
import TextLib
import TextMessages

enum HelperRouting {
    static func gate() -> HelperGate {
        HelperGate(
            appVersion: suiteVersion,
            requiredAccess: requiredAccess,
            hasAccess: { await StoreAccess.granted($0) },
            route: route
        )
    }

    @Sendable
    static func requiredAccess(_ envelope: HelperEnvelope) -> [StoreKind] {
        switch envelope.tool {
        case .text:
            (try? HelperCoding.decode(MessageHelperRequest.self, from: envelope.request))?.requiredAccess ?? [.messages]
        case .getClear:
            []
        case .reminders, .calendar, .contacts:
            envelope.tool.storeKind.map { [$0] } ?? []
        }
    }

    @Sendable
    static func route(_ envelope: HelperEnvelope) async -> HelperReply {
        switch envelope.tool {
        case .reminders:
            await dispatchReminderRequest(envelope.request, to: AppleReminderStore(EKEventStore()))
        case .calendar:
            await dispatchCalendarRequest(envelope.request, to: AppleCalendarStore(EKEventStore()))
        case .contacts:
            await dispatchContactRequest(envelope.request, to: AppleContactStore(store: CNContactStore()))
        case .text:
            await dispatchMessageRequest(
                envelope.request,
                to: AppleMessageSender(contacts: AppleContactStore(store: CNContactStore()))
            )
        case .getClear:
            await control(envelope.request)
        }
    }

    /// Liveness and permission checks that belong to no tool.
    private static func control(_ request: Data) async -> HelperReply {
        await HelperResponder.respond(
            to: request,
            as: HelperControlRequest.self,
            encodeToolError: { _ in nil },
            handle: { request in
                switch request {
                case .ping:
                    try HelperCoding.encode(HelperNoResult())
                case let .requestAccess(kind):
                    try await HelperCoding.encode(StoreAccess.granted(kind))
                }
            }
        )
    }
}
