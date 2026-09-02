// ReminderCommandShapes.swift
//
// CommandShape values for the reminders tool's argument-taking commands,
// consumed by GetClearKit's shared parseCommand. See
// specs/015-argument-shape/contracts/reminders-shapes.md for accepted/rejected forms.

import GetClearKit

public enum ReminderCommandShapes {
    public static let add = CommandShape(
        identifiers: [Identifier("title")],
        leading: .bareDate,
        keywords: [
            Keyword("list"),
            Keyword("priority"),
            Keyword("url"),
            Keyword("repeat", aliases: ["repeats", "repeating", "repeated"]),
            Keyword("due", aliases: ["date"])
        ],
        trailingTextKeyword: "note"
    )

    public static let change = CommandShape(
        identifiers: [Identifier("title")],
        leading: .bareDate,
        keywords: [
            Keyword("list"),
            Keyword("priority"),
            Keyword("url"),
            Keyword("repeat", aliases: ["repeats", "repeating", "repeated"]),
            Keyword("due", aliases: ["date"])
        ],
        trailingTextKeyword: "note"
    )

    public static let rename = CommandShape(
        identifiers: [Identifier("title"), Identifier("new title")],
        leading: .none,
        keywords: [Keyword("list")]
    )

    public static let remove = CommandShape(
        identifiers: [Identifier("title")],
        leading: .none,
        keywords: [Keyword("list")]
    )

    public static let done = CommandShape(
        identifiers: [Identifier("title")],
        leading: .none,
        keywords: [Keyword("list")]
    )

    public static let show = CommandShape(
        identifiers: [Identifier("title")],
        leading: .none,
        keywords: [Keyword("list")]
    )

    public static let list = CommandShape(
        identifiers: [Identifier("list", required: false)],
        leading: .none,
        keywords: [Keyword("by")]
    )

    public static let find = CommandShape(
        identifiers: [Identifier("query")],
        leading: .none
    )

    /// No identifiers, no keywords — any token at all is a stray token (#201).
    public static let lists = CommandShape()

    /// No identifiers, no keywords — any token at all is a stray token (#201).
    public static let open = CommandShape()
}
