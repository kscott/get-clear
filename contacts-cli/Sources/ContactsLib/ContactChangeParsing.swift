import ContactKit
import GetClearKit

private let changeKeywords: Set<String> = ["email", "phone", "company", "add", "remove"]

/// Parse a change specification (args after the contact name) into ContactChanges.
/// Syntax:
///   add email X / remove email X
///   email X Y  →  replaced(from: X, to: Y)
///   email X    →  added(X) when X is at end or followed by another keyword
///   email none →  cleared
///   Same patterns apply to phone and company (company value may contain spaces).
public func parseContactChanges(_ args: [String]) throws -> ContactChanges {
    var email:   ValueChange<String> = .unchanged
    var phone:   ValueChange<String> = .unchanged
    var company: ValueChange<String> = .unchanged

    var i = 0
    while i < args.count {
        switch args[i].lowercased() {
        case "add" where i + 2 < args.count:
            switch args[i + 1].lowercased() {
            case "email": email = .added(args[i + 2]); i += 3
            case "phone": phone = .added(args[i + 2]); i += 3
            default:      i += 1
            }
        case "remove" where i + 2 < args.count:
            switch args[i + 1].lowercased() {
            case "email": email = .removed(args[i + 2]); i += 3
            case "phone": phone = .removed(args[i + 2]); i += 3
            default:      i += 1
            }
        case "email" where i + 1 < args.count:
            let first = args[i + 1]
            if first.lowercased() == "none" {
                email = .cleared; i += 2
            } else if i + 2 < args.count && !changeKeywords.contains(args[i + 2].lowercased()) {
                email = .replaced(from: first, to: args[i + 2]); i += 3
            } else {
                email = .added(first); i += 2
            }
        case "phone" where i + 1 < args.count:
            let first = args[i + 1]
            if first.lowercased() == "none" {
                phone = .cleared; i += 2
            } else if i + 2 < args.count && !changeKeywords.contains(args[i + 2].lowercased()) {
                phone = .replaced(from: first, to: args[i + 2]); i += 3
            } else {
                phone = .added(first); i += 2
            }
        case "company" where i + 1 < args.count:
            var tokens: [String] = []
            var j = i + 1
            while j < args.count && !changeKeywords.contains(args[j].lowercased()) {
                tokens.append(args[j]); j += 1
            }
            let value = tokens.joined(separator: " ")
            company = value.lowercased() == "none" ? .cleared : .replaced(from: "", to: value)
            i = j
        default:
            i += 1
        }
    }

    guard email != .unchanged || phone != .unchanged || company != .unchanged else {
        throw ContactHandlerError.usage("nothing to change — specify email, phone, or company")
    }
    return ContactChanges(email: email, phone: phone, company: company)
}
