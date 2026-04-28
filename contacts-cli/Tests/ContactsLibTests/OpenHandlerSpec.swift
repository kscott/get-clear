import Quick
import Nimble
import Foundation
import ContactsLib

final class OpenHandlerSpec: QuickSpec {
    override class func spec() {
        describe("handleOpen") {
            it("opens the Contacts app URL") {
                var opened: URL?
                handleOpen(opener: { opened = $0 })
                expect(opened?.path) == "/System/Applications/Contacts.app"
            }
        }
    }
}
