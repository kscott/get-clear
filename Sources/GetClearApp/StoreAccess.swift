// StoreAccess.swift
//
// Asks macOS whether Get Clear holds each of its four permissions, prompting the user the first
// time (FR-004). Runs inside the helper, so every prompt and grant belongs to Get Clear.

import Contacts
import CoreServices
import EventKit
import GetClearKit

enum StoreAccess {
    static func granted(_ kind: StoreKind) async -> Bool {
        switch kind {
        case .reminders:
            await (try? EKEventStore().requestFullAccessToReminders()) ?? false
        case .calendars:
            await (try? EKEventStore().requestFullAccessToEvents()) ?? false
        case .contacts:
            await (try? CNContactStore().requestAccess(for: .contacts)) ?? false
        case .messages:
            await Task.detached { automationPermitted(bundleID: "com.apple.MobileSMS") }.value
        }
    }

    /// Asks for permission to send Apple Events to an app. Only an explicit refusal counts as
    /// denied; if Messages isn't running the answer is unknown, and osascript asks when it sends.
    private static func automationPermitted(bundleID: String) -> Bool {
        var address = AEAddressDesc()
        let status = bundleID.withCString { pointer in
            AECreateDesc(DescType(typeApplicationBundleID), pointer, bundleID.utf8.count, &address)
        }
        guard status == noErr else { return true }
        defer { AEDisposeDesc(&address) }
        let result = AEDeterminePermissionToAutomateTarget(&address, AEEventClass(typeWildCard), AEEventID(typeWildCard), true)
        return result != OSStatus(errAEEventNotPermitted)
    }
}
