import CoreGraphics

/// Converts a CGColor to a 6-character uppercase hex string.
/// Returns nil for nil input, unsupported color spaces, or insufficient components.
public func hexColor(from cgColor: CGColor?) -> String? {
    guard let cg = cgColor, let components = cg.components, !components.isEmpty else { return nil }
    let r, g, b: Int
    switch cg.colorSpace?.model {
    case .rgb where components.count >= 3:
        r = Int(components[0] * 255)
        g = Int(components[1] * 255)
        b = Int(components[2] * 255)
    case .monochrome where components.count >= 1:
        let w = Int(components[0] * 255)
        r = w
        g = w
        b = w
    default:
        return nil
    }
    return String(format: "%02X%02X%02X", r, g, b)
}
