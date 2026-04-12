// ChangeCommand.swift
//
// Parses a change input string into a value describing what fields should change.

import Foundation

/// Describes what should happen to a single contact field.
public enum FieldChange<T> {
    case unchanged
    case cleared
    case replaced(T)
    case added(T)
    case removed(T)
}

/// The result of parsing a change input string — what to apply to email and phone.
public struct ContactChanges {
    public let email: FieldChange<String>
    public let phone: FieldChange<String>
    /// Human-readable summary of each change, for use in confirmation output.
    public let descriptions: [String]
}

/// Errors thrown by parseContactChanges.
public enum ChangeError: Error {
    case nothingToChange
}

/// Parses a change input string and returns a ContactChanges describing what to apply.
/// Throws ChangeError.nothingToChange if no recognised fields are specified.
public func parseContactChanges(_ input: String) throws -> ContactChanges {
    var email: FieldChange<String> = .unchanged
    var phone: FieldChange<String> = .unchanged
    var descriptions: [String] = []

    if let r = input.range(of: #"\badd email\b"#, options: .regularExpression) {
        let val = input[r.upperBound...].trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: " ").first ?? ""
        if !val.isEmpty {
            email = .added(val)
            descriptions.append("email +\(val)")
        }
    } else if let r = input.range(of: #"\bremove email\b"#, options: .regularExpression) {
        let val = input[r.upperBound...].trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: " ").first ?? ""
        if !val.isEmpty {
            email = .removed(val)
            descriptions.append("email -\(val)")
        }
    } else if let r = input.range(of: #"\bemail\b"#, options: .regularExpression) {
        let val = input[r.upperBound...].trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: " ").first ?? ""
        if val.lowercased() == "none" {
            email = .cleared
            descriptions.append("email cleared")
        } else if !val.isEmpty {
            email = .replaced(val)
            descriptions.append("email → \(val)")
        }
    }

    if let r = input.range(of: #"\badd phone\b"#, options: .regularExpression) {
        let val = input[r.upperBound...].trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: " ").first ?? ""
        if !val.isEmpty {
            phone = .added(val)
            descriptions.append("phone +\(val)")
        }
    } else if let r = input.range(of: #"\bremove phone\b"#, options: .regularExpression) {
        let val = input[r.upperBound...].trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: " ").first ?? ""
        if !val.isEmpty {
            phone = .removed(val)
            descriptions.append("phone -\(val)")
        }
    } else if let r = input.range(of: #"\bphone\b"#, options: .regularExpression) {
        let val = input[r.upperBound...].trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: " ").first ?? ""
        if val.lowercased() == "none" {
            phone = .cleared
            descriptions.append("phone cleared")
        } else if !val.isEmpty {
            phone = .replaced(val)
            descriptions.append("phone → \(val)")
        }
    }

    guard !descriptions.isEmpty else { throw ChangeError.nothingToChange }
    return ContactChanges(email: email, phone: phone, descriptions: descriptions)
}
