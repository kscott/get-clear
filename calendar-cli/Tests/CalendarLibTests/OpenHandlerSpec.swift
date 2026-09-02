import CalendarLib
import Foundation
import Testing

@Suite("handleOpen")
struct OpenHandlerTests {
    @Test("opens the Calendar app URL")
    func opensCalendarAppURL() {
        var opened: URL?
        _ = handleOpen(opener: { opened = $0 })
        #expect(opened?.path == "/System/Applications/Calendar.app")
    }
}
