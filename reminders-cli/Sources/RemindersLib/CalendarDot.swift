// CalendarDot.swift
// Converts calendar colors to hex strings and renders them as ANSI-colored bullets.

import CoreGraphics
import GetClearKit

/// Converts a CGColor to a 6-character uppercase RGB hex string (e.g. "FF5733"). Returns nil for
/// non-RGB/monochrome color spaces or missing color data.
public func hexColor(from cgColor: CGColor?) -> String? {
    guard let cg = cgColor, let components = cg.components, !components.isEmpty else { return nil }
    let r, g, b: Int
    switch cg.colorSpace?.model {
    case .rgb where components.count >= 3:
        r = Int(components[0] * 255); g = Int(components[1] * 255); b = Int(components[2] * 255)
    case .monochrome where components.count >= 1:
        let w = Int(components[0] * 255); r = w; g = w; b = w
    default: return nil
    }
    return String(format: "%02X%02X%02X", r, g, b)
}

/// Returns a colored "●" ANSI prefix, or two spaces when ANSI is disabled or color is unavailable.
/// `hex` is a 6-character uppercase RGB hex string (e.g. "FF5733").
public func calendarDot(hex: String?, ansiEnabled: Bool) -> String {
    guard ansiEnabled, let hex = hex, hex.count == 6 else { return "  " }
    guard let r = UInt8(hex.prefix(2), radix: 16),
          let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
          let b = UInt8(hex.dropFirst(4).prefix(2), radix: 16) else { return "  " }
    return "\u{001B}[38;2;\(r);\(g);\(b)m●\u{001B}[0m "
}
