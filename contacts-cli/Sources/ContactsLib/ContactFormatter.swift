// ContactFormatter.swift
//
// Formats contact data for display output.

import GetClearKit

/// Returns display lines for a contact card. Caller is responsible for printing.
public func cardLines(for contact: ContactRecord) -> [String] {
    var lines: [String] = []
    let displayName = contact.name.isEmpty ? contact.company : contact.name
    lines.append(ANSI.bold(displayName))
    if !contact.company.isEmpty && !contact.name.isEmpty {
        lines.append("  \(ANSI.dim("Company:"))  \(contact.company)")
    }
    for (label, value) in contact.emails {
        let suffix = label.isEmpty ? "" : ANSI.dim(" (\(label))")
        lines.append("  \(ANSI.dim("Email:"))    \(value)\(suffix)")
    }
    for (label, value) in contact.phones {
        let suffix = label.isEmpty ? "" : ANSI.dim(" (\(label))")
        lines.append("  \(ANSI.dim("Phone:"))    \(value)\(suffix)")
    }
    return lines
}
