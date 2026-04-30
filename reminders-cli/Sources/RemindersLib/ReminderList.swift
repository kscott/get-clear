// ReminderList.swift
// A pure value type representing a reminder list, independent of EventKit.

public struct ReminderList: Equatable {
    public let identifier: String
    public let title: String
    /// Hex color string (e.g. "FF5733"), nil for backends without per-list color (Google Tasks).
    public let color: String?
    /// Account source name ("iCloud", "On My Mac"), nil for backends without source info (Google Tasks).
    /// Useful for disambiguation when multiple accounts contain a list with the same title.
    public let source: String?
    public let isModifiable: Bool

    public init(
        identifier: String = "",
        title: String,
        color: String? = nil,
        source: String? = nil,
        isModifiable: Bool = true
    ) {
        self.identifier = identifier
        self.title = title
        self.color = color
        self.source = source
        self.isModifiable = isModifiable
    }

    public func matches(identifier: String, title: String) -> Bool {
        self.identifier.isEmpty ? self.title == title : self.identifier == identifier
    }
}
