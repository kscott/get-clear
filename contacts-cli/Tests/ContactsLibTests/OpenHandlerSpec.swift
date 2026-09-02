import ContactsLib
import Foundation
import Testing

@Suite("handleOpen")
struct OpenHandlerTests {
    @Test("opens the Contacts app URL")
    func opensContactsAppURL() {
        var opened: URL?
        handleOpen(opener: { opened = $0 })
        #expect(opened?.path == "/System/Applications/Contacts.app")
    }
}
