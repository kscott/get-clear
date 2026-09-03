import CalendarLib
import Foundation
import Testing

@Suite("handleOpen")
struct OpenHandlerTests {
    @Test("opens the Calendar app URL")
    func opensCalendarAppURL() throws {
        var opened: URL?
        _ = try handleOpen(args: ["open"], opener: { opened = $0 })
        #expect(opened?.path == "/System/Applications/Calendar.app")
    }

    @Test("throws for a stray token after the command name and does not open")
    func throwsForStrayToken() {
        var opened: URL?
        #expect(throws: CalendarHandlerError.self) {
            try handleOpen(args: ["open", "extra"], opener: { opened = $0 })
        }
        #expect(opened == nil)
    }
}
