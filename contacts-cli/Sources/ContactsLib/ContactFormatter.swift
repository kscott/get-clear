import ContactKit
import GetClearKit

public func cardLines(for contact: Contact) -> [String] {
    var lines: [String] = []
    let displayName = contact.name.isEmpty ? contact.company : contact.name
    lines.append(ANSI.bold(displayName))
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

public func exportAddresses(_ contacts: [Contact]) -> String {
    contacts.compactMap { contact -> String? in
        guard let email = contact.emails.first?.value, !email.isEmpty else { return nil }
        let name = contact.name.isEmpty ? contact.company : contact.name
        return "\(name) <\(email)>"
    }.joined(separator: ", ")
}
