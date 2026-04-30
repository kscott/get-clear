// PhoneNormalizer.swift
// Phone number normalization and display formatting. No framework dependencies.

import Foundation

/// Normalize a phone number to E.164-ish format (+1XXXXXXXXXX for US numbers).
/// Returns the input unchanged if it can't be normalized.
public func normalizePhone(_ s: String) -> String {
    if s.contains("@") { return s }
    let digits = s.filter(\.isNumber)
    if digits.count == 10 { return "+1" + digits }
    if digits.count == 11, digits.hasPrefix("1") { return "+" + digits }
    if s.hasPrefix("+") { return "+" + digits }
    return s
}

/// Format a US phone number for display: "(555) 123-4567".
/// Returns the input unchanged if it can't be formatted.
public func formatPhone(_ s: String) -> String {
    let digits = s.filter(\.isNumber)
    let ten: Substring
    if digits.count == 11, digits.hasPrefix("1") {
        ten = digits.dropFirst()
    } else if digits.count == 10 {
        ten = digits[digits.startIndex...]
    } else {
        return s
    }
    return "(\(ten.prefix(3))) \(ten.dropFirst(3).prefix(3))-\(ten.dropFirst(6))"
}
