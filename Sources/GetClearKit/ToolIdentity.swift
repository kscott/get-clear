// ToolIdentity.swift
// A Get Clear tool's version and display identity.

public struct ToolIdentity: CustomStringConvertible {
    public let tool: String
    public let built: String
    public let summary: String

    public init(tool: String, built: String, summary: String) {
        self.tool = tool
        self.built = built
        self.summary = summary
    }

    public var description: String {
        if built == suiteVersion {
            return "\(tool) \(built) — \(summary)"
        }
        return "\(tool) \(built) (Get Clear \(suiteVersion)) — \(summary)"
    }
}
