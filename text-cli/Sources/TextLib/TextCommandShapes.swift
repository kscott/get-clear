// TextCommandShapes.swift
//
// CommandShape values for the text tool's argument-taking commands,
// consumed by GetClearKit's shared parseCommand. Adopts the argument-shape
// rule from spec 015 (Phase 2, #195).

import GetClearKit

public enum TextCommandShapes {
    public static let send = CommandShape(
        identifiers: [Identifier("contact")],
        trailingTextKeyword: "message",
        requiresTrailingText: true
    )

    public static let open = CommandShape.empty
}
