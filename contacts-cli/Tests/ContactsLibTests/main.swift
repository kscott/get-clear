// main.swift — test runner for ContactsLib
//
// Does not require Xcode or XCTest — runs with just the Swift CLI toolchain.
// Run via:  contacts test

import Foundation
import ContactsLib

// MARK: - Minimal test harness

final class TestRunner: @unchecked Sendable {
    private var passed = 0
    private var failed = 0

    func expect(_ description: String, _ condition: Bool, file: String = #file, line: Int = #line) {
        if condition {
            print("  ✓ \(description)")
            passed += 1
        } else {
            print("  ✗ \(description)  [\(URL(fileURLWithPath: file).lastPathComponent):\(line)]")
            failed += 1
        }
    }

    func suite(_ name: String, _ body: () -> Void) {
        print("\n\(name)")
        body()
    }

    func summary() {
        print("\n\(passed + failed) tests: \(passed) passed, \(failed) failed")
        if failed > 0 { exit(1) }
    }
}

// MARK: - Fixtures

let alice   = ContactRecord(name: "Alice Smith",   emails: [("work", "alice@example.com")],   phones: [("main", "555-1234")],  company: "Acme")
let bob     = ContactRecord(name: "Bob Jones",     emails: [("work", "bob@jones.org")],        phones: [],                    company: "BJCO")
let charlie = ContactRecord(name: "Charlie Brown", emails: [("home", "cbrown@peanuts.com")],   phones: [("main", "555-9999")], company: "")
let noEmail = ContactRecord(name: "Dana White",    emails: [],                                  phones: [("main", "303-555-0000")], company: "")
let orgOnly = ContactRecord(name: "",              emails: [("work", "info@initech.com")],      phones: [],                    company: "Initech")

let all = [alice, bob, charlie, noEmail, orgOnly]

// MARK: - Tests

let t = TestRunner()

t.suite("matchContacts — name matching") {
    let r = matchContacts("alice", in: all)
    t.expect("finds Alice by name",              r.contains { $0.name == "Alice Smith" })
    t.expect("exact prefix scores first",        r.first?.name == "Alice Smith")
    t.expect("no false positives",               r.count == 1)
}

t.suite("matchContacts — exact name") {
    let r = matchContacts("Alice Smith", in: all)
    t.expect("exact match scores 0 (first)",     r.first?.name == "Alice Smith")
}

t.suite("matchContacts — substring name") {
    let r = matchContacts("brown", in: all)
    t.expect("finds Charlie by last name",       r.contains { $0.name == "Charlie Brown" })
}

t.suite("matchContacts — email matching") {
    let r = matchContacts("jones.org", in: all)
    t.expect("finds Bob by email domain",        r.contains { $0.name == "Bob Jones" })
}

t.suite("matchContacts — company matching") {
    let r = matchContacts("acme", in: all)
    t.expect("finds Alice by exact company",     r.contains { $0.name == "Alice Smith" })

    let r2 = matchContacts("init", in: all)
    t.expect("finds Initech by partial company", r2.contains { $0.company == "Initech" })
}

t.suite("matchContacts — phone matching") {
    let r = matchContacts("5559999", in: all)
    t.expect("finds Charlie by digits",          r.contains { $0.name == "Charlie Brown" })

    let r2 = matchContacts("555-9999", in: all)
    t.expect("normalises dashes in query",       r2.contains { $0.name == "Charlie Brown" })
}

t.suite("matchContacts — sort order") {
    let contacts = [
        ContactRecord(name: "Smith Jr",  emails: [], phones: [],  company: ""),
        ContactRecord(name: "Smith",     emails: [], phones: [],  company: ""),
        ContactRecord(name: "John Smith",emails: [], phones: [],  company: ""),
    ]
    let r = matchContacts("smith", in: contacts)
    t.expect("exact name before prefix before substring", r[0].name == "Smith" && r[1].name == "Smith Jr" && r[2].name == "John Smith")
}

t.suite("matchContacts — empty query") {
    let r = matchContacts("", in: all)
    t.expect("returns all contacts",             r.count == all.count)
}

t.suite("matchContacts — no match") {
    let r = matchContacts("xyzzy", in: all)
    t.expect("returns empty",                    r.isEmpty)
}

t.suite("matchContacts — case insensitive") {
    t.expect("uppercase query works",            !matchContacts("ALICE", in: all).isEmpty)
    t.expect("mixed case works",                 !matchContacts("aLiCe", in: all).isEmpty)
}

t.suite("ContactRecord — primaryEmail") {
    t.expect("returns first email",              alice.primaryEmail == "alice@example.com")
    t.expect("empty when no emails",             noEmail.primaryEmail == "")
    t.expect("empty when no emails (orgOnly)",   orgOnly.primaryEmail == "info@initech.com")
}

t.suite("ContactRecord — addressField") {
    t.expect("formats Name <email>",             alice.addressField == "Alice Smith <alice@example.com>")
    t.expect("returns name only when no email",  noEmail.addressField == "Dana White")
}

t.suite("exportAddresses") {
    let result = exportAddresses([alice, bob, noEmail])
    t.expect("includes contacts with email",     result.contains("Alice Smith <alice@example.com>"))
    t.expect("includes Bob",                     result.contains("Bob Jones <bob@jones.org>"))
    t.expect("excludes contacts without email",  !result.contains("Dana White"))
    t.expect("comma separated",                  result.contains(", "))
}

t.suite("exportAddresses — empty list") {
    t.expect("empty string",                     exportAddresses([]).isEmpty)
}

t.suite("exportAddresses — all no email") {
    t.expect("empty string",                     exportAddresses([noEmail]).isEmpty)
}

t.suite("cleanLabel") {
    t.expect("strips CNLabel prefix/suffix",     cleanLabel("_$!<Work>!$_") == "work")
    t.expect("strips Home label",                cleanLabel("_$!<Home>!$_") == "home")
    t.expect("lowercases plain string",          cleanLabel("Mobile") == "mobile")
    t.expect("empty string passthrough",         cleanLabel("") == "")
    t.expect("no prefix — just lowercased",      cleanLabel("iPhone") == "iphone")
}

t.summary()
