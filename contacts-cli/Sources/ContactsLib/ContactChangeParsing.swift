import ContactKit
import GetClearKit

private let changeKeywords: Set<String> = ["email", "phone", "company", "add", "remove"]

/// Parse a change specification (args after the contact name) into ContactChanges.
/// Syntax:
///   add email X / remove email X
///   email X Y  →  replaced(from: X, to: Y)
///   email X    →  added(X) when X is at end or followed by another keyword
///   email none →  cleared
///   Same patterns apply to phone. company X → replaced(from: "", to: X); company none → cleared.
///
/// Distinct from GetClearKit's shared parseCommand (see ContactCommandShapes.swift):
/// email/phone are multi-value ValueChange fields — a contact can hold several — so their
/// syntax needs a two-token replace form (`email OLD NEW`) and an add/remove prefix that a
/// one-token-per-keyword parser can't express. This reuses GetClearKit's ArgumentError cases
/// for the errors it does share (unknown token, missing value, duplicate field) rather than
/// inventing its own wording.
public func parseContactChanges(_ args: [String]) throws -> ContactChanges {
    var email: ValueChange<String> = .unchanged
    var phone: ValueChange<String> = .unchanged
    var company: ValueChange<String> = .unchanged

    func apply(_ change: ValueChange<String>, toField field: String) throws {
        switch field {
        case "email":
            guard email == .unchanged else { throw wrap(.duplicateKeyword("email")) }
            email = change
        case "phone":
            guard phone == .unchanged else { throw wrap(.duplicateKeyword("phone")) }
            phone = change
        default:
            guard company == .unchanged else { throw wrap(.duplicateKeyword("company")) }
            company = change
        }
    }

    var i = 0
    while i < args.count {
        let token = args[i].lowercased()
        switch token {
        case "add", "remove":
            guard i + 1 < args.count else { throw wrap(.missingValue(keyword: token)) }
            let field = args[i + 1].lowercased()
            guard field == "email" || field == "phone" else { throw wrap(.unknownKeyword(args[i + 1])) }
            guard i + 2 < args.count else { throw wrap(.missingValue(keyword: field)) }
            let change: ValueChange<String> = token == "add" ? .added(args[i + 2]) : .removed(args[i + 2])
            try apply(change, toField: field)
            i += 3
        case "email", "phone":
            guard i + 1 < args.count else { throw wrap(.missingValue(keyword: token)) }
            let first = args[i + 1]
            let change: ValueChange<String>
            let consumed: Int
            if first.lowercased() == "none" {
                change = .cleared
                consumed = 2
            } else if i + 2 < args.count, !changeKeywords.contains(args[i + 2].lowercased()) {
                change = .replaced(from: first, to: args[i + 2])
                consumed = 3
            } else {
                change = .added(first)
                consumed = 2
            }
            try apply(change, toField: token)
            i += consumed
        case "company":
            guard i + 1 < args.count else { throw wrap(.missingValue(keyword: "company")) }
            let value = args[i + 1]
            let change: ValueChange<String> = value.lowercased() == "none" ? .cleared : .replaced(from: "", to: value)
            try apply(change, toField: "company")
            i += 2
        default:
            throw wrap(.unknownKeyword(args[i]))
        }
    }

    guard email != .unchanged || phone != .unchanged || company != .unchanged else {
        throw ContactHandlerError.usage("nothing to change — specify email, phone, or company")
    }
    return ContactChanges(email: email, phone: phone, company: company)
}

private func wrap(_ error: ArgumentError) -> ContactHandlerError {
    .usage(error.message)
}
