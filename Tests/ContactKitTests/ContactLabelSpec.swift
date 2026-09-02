// ContactLabelSpec.swift

import ContactKit
import Testing

@Suite("cleanLabel")
struct CleanLabelTests {
    @Test("strips Apple CNLabel delimiters from a wrapped label")
    func stripsWrappedDelimiters() {
        #expect(cleanLabel("_$!<Home>!$_") == "home")
    }

    @Test("strips delimiters from a phone label")
    func stripsPhoneLabelDelimiters() {
        #expect(cleanLabel("_$!<Mobile>!$_") == "mobile")
    }

    @Test("lowercases a plain label with no delimiters")
    func lowercasesPlainLabel() {
        #expect(cleanLabel("Work") == "work")
    }

    @Test("returns an already-clean label unchanged except lowercased")
    func alreadyCleanLabel() {
        #expect(cleanLabel("home") == "home")
    }

    @Test("returns an empty string unchanged")
    func emptyStringUnchanged() {
        #expect(cleanLabel("") == "")
    }

    @Test("strips prefix only when suffix is absent")
    func stripsPrefixOnly() {
        #expect(cleanLabel("_$!<Work") == "work")
    }

    @Test("strips suffix only when prefix is absent")
    func stripsSuffixOnly() {
        #expect(cleanLabel("Work>!$_") == "work")
    }
}
