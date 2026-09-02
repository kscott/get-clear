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
}
