import ContactKit
import ContactsLib
import GetClearKit
import Testing

@Suite("parseContactChanges")
struct ContactChangeParsingTests {
    @Suite("email: add")
    struct EmailAdd {
        @Test("returns added case for 'add email X'")
        func returnsAddedForAddEmail() throws {
            let c = try parseContactChanges(["add", "email", "alice@example.com"])
            #expect(c.email == .added("alice@example.com"))
        }

        @Test("leaves phone unchanged when only email is specified")
        func leavesPhoneUnchanged() throws {
            let c = try parseContactChanges(["add", "email", "alice@example.com"])
            #expect(c.phone == .unchanged)
        }
    }

    @Suite("email: remove")
    struct EmailRemove {
        @Test("returns removed case for 'remove email X'")
        func returnsRemovedForRemoveEmail() throws {
            let c = try parseContactChanges(["remove", "email", "alice@example.com"])
            #expect(c.email == .removed("alice@example.com"))
        }
    }

    @Suite("email: replace")
    struct EmailReplace {
        @Test("returns replaced case for 'email OLD NEW'")
        func returnsReplacedForEmailOldNew() throws {
            let c = try parseContactChanges(["email", "old@example.com", "new@example.com"])
            #expect(c.email == .replaced(from: "old@example.com", to: "new@example.com"))
        }
    }

    @Suite("email: single token")
    struct EmailSingleToken {
        @Test("treats 'email X' at end of args as added")
        func treatsEmailXAsAdded() throws {
            let c = try parseContactChanges(["email", "alice@example.com"])
            #expect(c.email == .added("alice@example.com"))
        }
    }

    @Suite("email: clear")
    struct EmailClear {
        @Test("returns cleared for 'email none'")
        func returnsClearedForEmailNone() throws {
            let c = try parseContactChanges(["email", "none"])
            #expect(c.email == .cleared)
        }
    }

    @Suite("phone: add")
    struct PhoneAdd {
        @Test("returns added case for 'add phone P'")
        func returnsAddedForAddPhone() throws {
            let c = try parseContactChanges(["add", "phone", "555-1234"])
            #expect(c.phone == .added("555-1234"))
        }

        @Test("leaves email unchanged when only phone is specified")
        func leavesEmailUnchanged() throws {
            let c = try parseContactChanges(["add", "phone", "555-1234"])
            #expect(c.email == .unchanged)
        }
    }

    @Suite("phone: remove")
    struct PhoneRemove {
        @Test("returns removed case for 'remove phone P'")
        func returnsRemovedForRemovePhone() throws {
            let c = try parseContactChanges(["remove", "phone", "555-1234"])
            #expect(c.phone == .removed("555-1234"))
        }
    }

    @Suite("phone: replace")
    struct PhoneReplace {
        @Test("returns replaced case for 'phone OLD NEW'")
        func returnsReplacedForPhoneOldNew() throws {
            let c = try parseContactChanges(["phone", "555-0000", "555-1111"])
            #expect(c.phone == .replaced(from: "555-0000", to: "555-1111"))
        }
    }

    @Suite("phone: clear")
    struct PhoneClear {
        @Test("returns cleared for 'phone none'")
        func returnsClearedForPhoneNone() throws {
            let c = try parseContactChanges(["phone", "none"])
            #expect(c.phone == .cleared)
        }
    }

    @Suite("company")
    struct CompanyChanges {
        @Test("returns replaced for 'company Acme Corp'")
        func returnsReplacedForCompany() throws {
            let c = try parseContactChanges(["company", "Acme", "Corp"])
            #expect(c.company == .replaced(from: "", to: "Acme Corp"))
        }

        @Test("returns cleared for 'company none'")
        func returnsClearedForCompanyNone() throws {
            let c = try parseContactChanges(["company", "none"])
            #expect(c.company == .cleared)
        }
    }

    @Suite("combined")
    struct Combined {
        @Test("handles email and phone in one call")
        func handlesEmailAndPhone() throws {
            let c = try parseContactChanges(["email", "alice@example.com", "phone", "555-1234"])
            #expect(c.email == .added("alice@example.com"))
            #expect(c.phone == .added("555-1234"))
        }
    }

    @Suite("empty input")
    struct EmptyInput {
        @Test("throws when no fields are specified")
        func throwsWhenNoFields() {
            #expect(throws: (any Error).self) { try parseContactChanges([]) }
        }
    }
}
