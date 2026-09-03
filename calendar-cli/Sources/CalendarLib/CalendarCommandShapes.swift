// CalendarCommandShapes.swift
//
// CommandShape values for the calendar tool's argument-taking commands,
// consumed by GetClearKit's shared parseCommand. Adopts the argument-shape
// rule from spec 015 (Phase 2, #192).

import GetClearKit

public enum CalendarCommandShapes {
    public static let add = CommandShape(
        identifiers: [Identifier("title")],
        leading: .bareDateRange
    )

    public static let find = CommandShape(
        identifiers: [Identifier("query")],
        leading: .bareDateRange
    )

    public static let show = CommandShape(
        identifiers: [Identifier("title")],
        leading: .bareDateRange
    )

    public static let remove = CommandShape(
        identifiers: [Identifier("title")],
        leading: .bareDateRange
    )

    /// The range is required, but the parser doesn't enforce that — the handler checks
    /// `bareDateRange != nil` itself, same as any other value validation (FR-024).
    public static let list = CommandShape(
        leading: .bareDateRange
    )

    public static let next = CommandShape(
        identifiers: [Identifier("count", required: false)]
    )

    /// No identifiers, no keywords — any token at all is a stray token.
    public static let today = CommandShape()

    /// No identifiers, no keywords — any token at all is a stray token.
    public static let week = CommandShape()

    /// No identifiers, no keywords — any token at all is a stray token.
    public static let calendars = CommandShape()

    /// No identifiers, no keywords — any token at all is a stray token.
    public static let setup = CommandShape()

    /// No identifiers, no keywords — any token at all is a stray token.
    public static let open = CommandShape()
}
