import Quick
import Nimble
import Foundation
import CalendarLib

final class CalendarOpenHandlerSpec: QuickSpec {
    override class func spec() {
        describe("handleOpen") {
            it("opens the Calendar app URL") {
                var opened: URL?
                _ = handleOpen(opener: { opened = $0 })
                expect(opened?.path) == "/System/Applications/Calendar.app"
            }
        }
    }
}
