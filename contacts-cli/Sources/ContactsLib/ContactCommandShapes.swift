// ContactCommandShapes.swift
//
// CommandShape values for the contacts tool's argument-taking commands,
// consumed by GetClearKit's shared parseCommand. Adopts the argument-shape
// rule from spec 015 (Phase 2, #193).
//
// `change` has no shape here — its field syntax (add/remove email, the
// two-token replace form, multi-value ValueChange fields) doesn't fit the
// one-token-per-keyword model. See ContactChangeParsing.swift.

import GetClearKit

public enum ContactCommandShapes {
    public static let add = CommandShape(
        identifiers: [Identifier("name")],
        keywords: [Keyword("email"), Keyword("phone"), Keyword("company"), Keyword("to")]
    )

    public static let rename = CommandShape(
        identifiers: [Identifier("name"), Identifier("new name")]
    )

    public static let remove = CommandShape(
        identifiers: [Identifier("name")],
        keywords: [Keyword("from")]
    )

    public static let find = CommandShape(identifiers: [Identifier("query")])

    public static let show = CommandShape(identifiers: [Identifier("name")])

    public static let list = CommandShape(identifiers: [Identifier("group")])

    public static let lists = CommandShape.empty

    public static let open = CommandShape.empty
}
