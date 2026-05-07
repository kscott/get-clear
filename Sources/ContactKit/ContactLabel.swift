// ContactLabel.swift

/// Strips Apple's CNLabel wrapping delimiters (e.g. "_$!<Home>!$_" → "home").
public func cleanLabel(_ raw: String) -> String {
    var s = raw
    if s.hasPrefix("_$!<") { s = String(s.dropFirst(4)) }
    if s.hasSuffix(">!$_") { s = String(s.dropLast(4)) }
    return s.lowercased()
}
