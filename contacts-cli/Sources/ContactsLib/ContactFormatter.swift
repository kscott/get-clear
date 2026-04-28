import ContactKit
import GetClearKit

public func cardLines(for contact: Contact) -> [String] {
    var lines: [String] = []
    lines.append(ANSI.bold(contact.displayName))
    if !contact.company.isEmpty && !contact.name.isEmpty {
        lines.append("  \(ANSI.dim("Company:"))  \(contact.company)")
    }
    for field in contact.emails {
        let suffix = field.label.isEmpty ? "" : ANSI.dim(" (\(field.label))")
        lines.append("  \(ANSI.dim("Email:"))    \(field.value)\(suffix)")
    }
    for field in contact.phones {
        let suffix = field.label.isEmpty ? "" : ANSI.dim(" (\(field.label))")
        lines.append("  \(ANSI.dim("Phone:"))    \(field.value)\(suffix)")
    }
    return lines
}
