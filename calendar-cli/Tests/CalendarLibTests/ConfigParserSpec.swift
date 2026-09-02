// ConfigParserSpec.swift
//
// Tests for CalendarLib ConfigParser — TOML config parsing into CalendarConfig.

import CalendarLib
import Foundation
import Testing

@Suite("parseConfig")
struct ConfigParserTests {
    @Suite("empty or missing config")
    struct EmptyOrMissingConfig {
        @Test("returns no subsets for empty content")
        func noSubsetsForEmpty() {
            #expect(parseConfig("").subsets.isEmpty)
        }
    }

    @Suite("basic subsets")
    struct BasicSubsets {
        let toml = """
        [subsets]
        work     = ["Work", "Meetings"]
        personal = ["Home", "Family", "Birthdays & Anniversaries"]
        """

        @Test("parses the work subset")
        func parsesWorkSubset() {
            #expect(parseConfig(toml).subsets["work"] != nil)
        }

        @Test("work subset has 2 calendars")
        func workSubsetCount() {
            #expect(parseConfig(toml).subsets["work"]?.count == 2)
        }

        @Test("work subset includes Work")
        func workSubsetIncludesWork() {
            #expect(parseConfig(toml).subsets["work"]?.contains("Work") == true)
        }

        @Test("work subset includes Meetings")
        func workSubsetIncludesMeetings() {
            #expect(parseConfig(toml).subsets["work"]?.contains("Meetings") == true)
        }

        @Test("personal subset has 3 calendars")
        func personalSubsetCount() {
            #expect(parseConfig(toml).subsets["personal"]?.count == 3)
        }

        @Test("personal subset includes calendar names with special characters")
        func personalSubsetSpecialChars() {
            #expect(parseConfig(toml).subsets["personal"]?.contains("Birthdays & Anniversaries") == true)
        }
    }

    @Suite("subset key casing")
    struct SubsetKeyCasing {
        let toml = """
        [subsets]
        Work = ["Work"]
        """

        @Test("lowercases subset keys")
        func lowercasesKeys() {
            #expect(parseConfig(toml).subsets["work"] != nil)
        }

        @Test("does not store the original-case key")
        func noOriginalCaseKey() {
            #expect(parseConfig(toml).subsets["Work"] == nil)
        }
    }

    @Suite("non-subsets sections")
    struct NonSubsetsSections {
        let toml = """
        [other]
        foo = ["bar"]
        
        [subsets]
        personal = ["Home"]
        """

        @Test("ignores sections other than [subsets]")
        func ignoresOtherSections() {
            #expect(parseConfig(toml).subsets.count == 1)
        }

        @Test("parses the subsets section correctly")
        func parsesSubsetsSection() {
            #expect(parseConfig(toml).subsets["personal"] != nil)
        }

        @Test("does not parse keys from other sections")
        func noKeysFromOtherSections() {
            #expect(parseConfig(toml).subsets["foo"] == nil)
        }
    }

    @Suite("comments and blank lines")
    struct CommentsAndBlankLines {
        let toml = """
        # This is a comment
        
        [subsets]
        # another comment
        work = ["Work"]
        """

        @Test("ignores comments and blank lines")
        func ignoresCommentsAndBlanks() {
            #expect(parseConfig(toml).subsets["work"] != nil)
        }
    }
}
