// MailCommandShapes.swift
//
// CommandShape values for the mail tool's argument-taking commands,
// consumed by GetClearKit's shared parseCommand. Adopts the argument-shape
// rule from spec 015 (Phase 2, #194).

import GetClearKit

public enum MailCommandShapes {
    /// Shared by send and draft — draft composes and saves the same message instead of
    /// sending it (design.md: --draft was the suite's one open flag violation; mail draft
    /// is the fix). cc/attach are repeatable — a message can go to several cc'd people or
    /// carry several attachments, unlike every other keyword in the suite so far.
    public static let send = CommandShape(
        identifiers: [Identifier("to")],
        keywords: [
            Keyword("cc", repeatable: true),
            Keyword("subject"),
            Keyword("attach", repeatable: true)
        ],
        trailingTextKeyword: "body",
        requiresTrailingText: true
    )

    public static let draft = send

    public static let find = CommandShape(identifiers: [Identifier("query")])

    /// No identifiers, no keywords — any token at all is a stray token.
    public static let open = CommandShape.empty
}
