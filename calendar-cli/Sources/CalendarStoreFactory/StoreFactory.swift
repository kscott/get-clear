// StoreFactory.swift
//
// Constructs the CalendarStore a command uses (spec 018). Inside Get Clear.app, every call goes
// through the helper, which holds the Calendars permission. Anywhere else (a development build),
// the command accesses Calendars directly, as before.

import CalendarEventKit
import CalendarLib
import GetClearKit
import HelperXPC

public func makeCalendarStore() async throws -> any CalendarStore {
    switch AccessRoute.decide(resolvedExecutable: HelperClient.resolvedExecutableURL()) {
    case let .helper(appURL):
        RemoteCalendarStore(transport: HelperClient.transport(appURL: appURL), appVersion: suiteVersion)
    case .direct:
        try await AppleCalendarStore.authorized()
    }
}
