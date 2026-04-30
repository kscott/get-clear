// CalendarDot.swift

import GetClearKit

/// Returns a colored "●" ANSI prefix, or two spaces when ANSI is disabled or color is unavailable.
/// `hex` is a 6-character uppercase RGB hex string (e.g. "FF5733").
public func calendarDot(hex: String?, ansiEnabled: Bool) -> String {
    guard ansiEnabled, let hex, hex.count == 6 else { return "  " }
    guard let r = UInt8(hex.prefix(2), radix: 16),
          let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
          let b = UInt8(hex.dropFirst(4).prefix(2), radix: 16) else { return "  " }
    return "\u{001B}[38;2;\(r);\(g);\(b)m●\u{001B}[0m "
}
