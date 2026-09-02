import ContactsLib
import Testing

@Suite("ContactHandlerError")
struct ContactHandlerErrorTests {
    @Test("usage error description returns the message")
    func usageErrorDescription() {
        let error = ContactHandlerError.usage("provide a contact name")
        #expect(error.localizedDescription == "provide a contact name")
    }
}
