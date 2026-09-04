import ContactsLib
import Foundation
import Testing

@Suite("handleOpen")
struct OpenHandlerTests {
    @Test("opens the Contacts app URL")
    func opensContactsAppURL() throws {
        var opened: URL?
        try handleOpen(args: ["open"], opener: { opened = $0 })
        #expect(opened?.path == "/System/Applications/Contacts.app")
    }

    @Test("throws for a stray token after the command name and does not open")
    func throwsForStrayToken() {
        var opened: URL?
        #expect(throws: (any Error).self) {
            try handleOpen(args: ["open", "extra"], opener: { opened = $0 })
        }
        #expect(opened == nil)
    }
}
