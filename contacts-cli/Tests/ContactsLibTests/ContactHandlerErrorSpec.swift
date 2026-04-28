import Quick
import Nimble
import ContactsLib

final class ContactHandlerErrorSpec: QuickSpec {
    override class func spec() {
        describe("ContactHandlerError") {
            it("usage error description returns the message") {
                let error = ContactHandlerError.usage("provide a contact name")
                expect(error.localizedDescription) == "provide a contact name"
            }
        }
    }
}
