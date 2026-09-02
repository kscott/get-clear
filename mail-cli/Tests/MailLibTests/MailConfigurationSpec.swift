// MailConfigurationSpec.swift
//
// Tests for MailLib MailConfiguration — config parsing and model types.

import Foundation
import MailLib
import Testing

private let wellFormedTOML = """
default_from = "alice@example.com"

[identities]
id1 = "alice@example.com|Alice"
id2 = "bob@example.com|Bob"

[other]
key = "value"
"""

@Suite("parseConfig")
struct ParseConfigTests {
    @Suite("a well-formed config")
    struct WellFormedConfig {
        let toml = wellFormedTOML

        @Test("parses the default_from field")
        func parsesDefaultFrom() {
            #expect(parseConfig(toml).defaultFrom == "alice@example.com")
        }

        @Test("parses identity email")
        func parsesIdentityEmail() {
            #expect(parseConfig(toml).identities.first?.email == "alice@example.com")
        }

        @Test("parses identity name")
        func parsesIdentityName() {
            #expect(parseConfig(toml).identities.first?.name == "Alice")
        }

        @Test("parses identity id")
        func parsesIdentityId() {
            #expect(parseConfig(toml).identities.first?.id == "id1")
        }

        @Test("parses multiple identities")
        func parsesMultipleIdentities() {
            #expect(parseConfig(toml).identities.count == 2)
        }
    }

    @Suite("identity with a pipe in the name")
    struct IdentityWithPipeInName {
        let toml = """
        default_from = "a@b.com"
        
        [identities]
        id1 = "a@b.com|First|Last"
        """

        @Test("joins pipe-separated name parts")
        func joinsPipeSeparatedNameParts() {
            #expect(parseConfig(toml).identities.first?.name == "First|Last")
        }
    }

    @Suite("web_app_url field")
    struct WebAppURLField {
        let toml = """
        default_from = "alice@example.com"
        web_app_url = "https://mail.google.com"
        
        [identities]
        id1 = "alice@example.com|Ken Scott"
        """

        @Test("parses a custom web app URL")
        func parsesCustomWebAppURL() {
            #expect(parseConfig(toml).webAppURL == URL(string: "https://mail.google.com"))
        }
    }

    @Suite("missing web_app_url")
    struct MissingWebAppURL {
        @Test("defaults to the Fastmail URL")
        func defaultsToFastmailURL() {
            #expect(parseConfig("").webAppURL == MailConfig.defaultWebAppURL)
        }
    }

    @Suite("empty config")
    struct EmptyConfig {
        @Test("returns empty defaultFrom")
        func emptyDefaultFrom() {
            #expect(parseConfig("").defaultFrom == "")
        }

        @Test("returns no identities")
        func noIdentities() {
            #expect(parseConfig("").identities.isEmpty)
        }
    }

    @Suite("lines with comments and blank lines")
    struct CommentsAndBlankLines {
        let toml = """
        # this is a comment
        default_from = "x@y.com"
        
        [identities]
        # another comment
        id1 = "x@y.com|X Y"
        """

        @Test("ignores comment lines")
        func ignoresCommentLines() {
            #expect(parseConfig(toml).defaultFrom == "x@y.com")
        }

        @Test("still parses identity")
        func stillParsesIdentity() {
            #expect(parseConfig(toml).identities.count == 1)
        }
    }

    @Suite("a second section header after [identities]")
    struct SecondSectionHeader {
        @Test("ignores keys under non-identities sections")
        func ignoresKeysUnderOtherSections() {
            #expect(parseConfig(wellFormedTOML).identities.count == 2)
        }

        @Test("does not treat other-section keys as identities")
        func doesNotTreatOtherKeysAsIdentities() {
            #expect(!parseConfig(wellFormedTOML).identities.map(\.id).contains("key"))
        }
    }

    @Suite("identity line with too few parts")
    struct IdentityLineTooFewParts {
        let toml = """
        default_from = "a@b.com"
        
        [identities]
        id1 = "a@b.com"
        """

        @Test("skips malformed identity entries")
        func skipsMalformedIdentityEntries() {
            #expect(parseConfig(toml).identities.isEmpty)
        }
    }
}

@Suite("MailConfig.identity(for:)")
struct MailConfigIdentityForTests {
    let config = parseConfig(wellFormedTOML)

    @Test("finds identity by exact email")
    func findsByExactEmail() {
        #expect(config.identity(for: "alice@example.com")?.id == "id1")
    }

    @Test("finds identity case-insensitively")
    func findsCaseInsensitively() {
        #expect(config.identity(for: "ALICE@EXAMPLE.COM")?.id == "id1")
    }

    @Test("returns nil for unknown email")
    func nilForUnknownEmail() {
        #expect(config.identity(for: "nobody@nowhere.com") == nil)
    }
}

@Suite("MailIdentity.displayLabel")
struct MailIdentityDisplayLabelTests {
    @Test("returns 'email (name)' when name is present")
    func emailAndNameWhenPresent() {
        let id = MailIdentity(id: "id1", email: "alice@example.com", name: "Ken Scott")
        #expect(id.displayLabel == "alice@example.com (Ken Scott)")
    }

    @Test("returns just email when name is empty")
    func justEmailWhenNameEmpty() {
        let id = MailIdentity(id: "id1", email: "alice@example.com", name: "")
        #expect(id.displayLabel == "alice@example.com")
    }
}

@Suite("serializeConfig")
struct SerializeConfigTests {
    let config = MailConfig(
        defaultFrom: "alice@example.com",
        identities: [
            MailIdentity(id: "id1", email: "alice@example.com", name: "Alice"),
            MailIdentity(id: "id2", email: "bob@example.com", name: "Bob")
        ]
    )

    @Test("round-trips through parseConfig")
    func roundTripsThroughParseConfig() {
        #expect(parseConfig(serializeConfig(config)).defaultFrom == config.defaultFrom)
    }

    @Test("round-trips identities")
    func roundTripsIdentities() {
        #expect(parseConfig(serializeConfig(config)).identities.count == config.identities.count)
    }

    @Test("includes default_from")
    func includesDefaultFrom() {
        #expect(serializeConfig(config).contains("default_from = \"alice@example.com\""))
    }

    @Test("includes web_app_url")
    func includesWebAppURL() {
        #expect(serializeConfig(config).contains("web_app_url = \"https://app.fastmail.com\""))
    }

    @Test("includes identity lines")
    func includesIdentityLines() {
        #expect(serializeConfig(config).contains("id1 = \"alice@example.com|Alice\""))
    }

    @Test("includes the identities section header")
    func includesIdentitiesSectionHeader() {
        #expect(serializeConfig(config).contains("[identities]"))
    }
}

@Suite("MailConfig.defaultIdentity")
struct MailConfigDefaultIdentityTests {
    @Test("returns the identity matching defaultFrom")
    func returnsMatchingIdentity() {
        let config = parseConfig("""
        default_from = "alice@example.com"
        
        [identities]
        id1 = "alice@example.com|Ken Scott"
        """)
        #expect(config.defaultIdentity?.id == "id1")
    }

    @Test("returns nil when defaultFrom has no matching identity")
    func nilWhenNoMatch() {
        let config = parseConfig("""
        default_from = "nobody@example.com"
        
        [identities]
        id1 = "alice@example.com|Ken Scott"
        """)
        #expect(config.defaultIdentity == nil)
    }
}
