// OpenHandlerSpec.swift

import Foundation
import GetClearKit
import RemindersLib
import Testing

@Suite("handleOpen")
struct OpenHandlerTests {
    @Test("calls the opener with the Reminders app URL")
    func callsOpenerWithRemindersURL() throws {
        var opened: URL?
        try handleOpen(args: ["open"], opener: { opened = $0 })
        #expect(opened == URL(fileURLWithPath: "/System/Applications/Reminders.app"))
    }

    @Test("throws for a stray token after the command name and does not open")
    func throwsForStrayToken() {
        var opened: URL?
        #expect(throws: ReminderHandlerError.self) {
            try handleOpen(args: ["open", "app"], opener: { opened = $0 })
        }
        #expect(opened == nil)
    }
}
