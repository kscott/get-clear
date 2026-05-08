// MailConfigurationSpec.swift
//
// Tests for MailLib MailConfiguration — config parsing and model types.

import Foundation
import MailLib
import Nimble
import Quick

final class MailConfigurationSpec: QuickSpec {
    override class func spec() {
        describe("parseConfig") {
            context("a well-formed config") {
                let toml = """
                default_from = "alice@example.com"
                
                [identities]
                id1 = "alice@example.com|Ken Scott"
                id2 = "bob@example.com|Kenneth"
                """

                it("parses the default_from field") {
                    expect(parseConfig(toml).defaultFrom) == "alice@example.com"
                }

                it("parses identity email") {
                    expect(parseConfig(toml).identities.first?.email) == "alice@example.com"
                }

                it("parses identity name") {
                    expect(parseConfig(toml).identities.first?.name) == "Ken Scott"
                }

                it("parses identity id") {
                    expect(parseConfig(toml).identities.first?.id) == "id1"
                }

                it("parses multiple identities") {
                    expect(parseConfig(toml).identities.count) == 2
                }
            }

            context("identity with a pipe in the name") {
                let toml = """
                default_from = "a@b.com"
                
                [identities]
                id1 = "a@b.com|First|Last"
                """

                it("joins pipe-separated name parts") {
                    expect(parseConfig(toml).identities.first?.name) == "First|Last"
                }
            }

            context("web_app_url field") {
                let toml = """
                default_from = "alice@example.com"
                web_app_url = "https://mail.google.com"
                
                [identities]
                id1 = "alice@example.com|Ken Scott"
                """

                it("parses a custom web app URL") {
                    expect(parseConfig(toml).webAppURL) == URL(string: "https://mail.google.com")
                }
            }

            context("missing web_app_url") {
                it("defaults to the Fastmail URL") {
                    expect(parseConfig("").webAppURL) == MailConfig.defaultWebAppURL
                }
            }

            context("empty config") {
                it("returns empty defaultFrom") {
                    expect(parseConfig("").defaultFrom) == ""
                }

                it("returns no identities") {
                    expect(parseConfig("").identities).to(beEmpty())
                }
            }

            context("lines with comments and blank lines") {
                let toml = """
                # this is a comment
                default_from = "x@y.com"
                
                [identities]
                # another comment
                id1 = "x@y.com|X Y"
                """

                it("ignores comment lines") {
                    expect(parseConfig(toml).defaultFrom) == "x@y.com"
                }

                it("still parses identity") {
                    expect(parseConfig(toml).identities.count) == 1
                }
            }

            context("identity line with too few parts") {
                let toml = """
                default_from = "a@b.com"
                
                [identities]
                id1 = "a@b.com"
                """

                it("skips malformed identity entries") {
                    expect(parseConfig(toml).identities).to(beEmpty())
                }
            }
        }

        describe("MailConfig.identity(for:)") {
            let config = parseConfig("""
            default_from = "alice@example.com"
            
            [identities]
            id1 = "alice@example.com|Ken Scott"
            id2 = "bob@example.com|Kenneth"
            """)

            it("finds identity by exact email") {
                expect(config.identity(for: "alice@example.com")?.id) == "id1"
            }

            it("finds identity case-insensitively") {
                expect(config.identity(for: "ALICE@EXAMPLE.COM")?.id) == "id1"
            }

            it("returns nil for unknown email") {
                expect(config.identity(for: "nobody@nowhere.com")).to(beNil())
            }
        }

        describe("MailIdentity.displayLabel") {
            it("returns 'email (name)' when name is present") {
                let id = MailIdentity(id: "id1", email: "alice@example.com", name: "Ken Scott")
                expect(id.displayLabel) == "alice@example.com (Ken Scott)"
            }
            it("returns just email when name is empty") {
                let id = MailIdentity(id: "id1", email: "alice@example.com", name: "")
                expect(id.displayLabel) == "alice@example.com"
            }
        }

        describe("serializeConfig") {
            let config = MailConfig(
                defaultFrom: "alice@example.com",
                identities: [
                    MailIdentity(id: "id1", email: "alice@example.com", name: "Alice"),
                    MailIdentity(id: "id2", email: "bob@example.com", name: "Bob")
                ]
            )

            it("round-trips through parseConfig") {
                expect(parseConfig(serializeConfig(config)).defaultFrom) == config.defaultFrom
            }
            it("round-trips identities") {
                expect(parseConfig(serializeConfig(config)).identities.count) == config.identities.count
            }
            it("includes default_from") {
                expect(serializeConfig(config)).to(contain("default_from = \"alice@example.com\""))
            }
            it("includes web_app_url") {
                expect(serializeConfig(config)).to(contain("web_app_url = \"https://app.fastmail.com\""))
            }
            it("includes identity lines") {
                expect(serializeConfig(config)).to(contain("id1 = \"alice@example.com|Alice\""))
            }
            it("includes the identities section header") {
                expect(serializeConfig(config)).to(contain("[identities]"))
            }
        }

        describe("MailConfig.defaultIdentity") {
            it("returns the identity matching defaultFrom") {
                let config = parseConfig("""
                default_from = "alice@example.com"
                
                [identities]
                id1 = "alice@example.com|Ken Scott"
                """)
                expect(config.defaultIdentity?.id) == "id1"
            }

            it("returns nil when defaultFrom has no matching identity") {
                let config = parseConfig("""
                default_from = "nobody@example.com"
                
                [identities]
                id1 = "alice@example.com|Ken Scott"
                """)
                expect(config.defaultIdentity).to(beNil())
            }
        }
    }
}
