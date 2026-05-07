import CoreGraphics

public func rgbComponents(from cgColor: CGColor?) -> (r: Int, g: Int, b: Int)? {
    guard let cg = cgColor, let components = cg.components, !components.isEmpty else { return nil }
    switch cg.colorSpace?.model {
    case .rgb where components.count >= 3:
        return (Int(components[0] * 255), Int(components[1] * 255), Int(components[2] * 255))
    case .monochrome where components.count >= 1:
        let w = Int(components[0] * 255)
        return (w, w, w)
    default:
        return nil
    }
}

public func hexColor(from cgColor: CGColor?) -> String? {
    guard let (r, g, b) = rgbComponents(from: cgColor) else { return nil }
    return String(format: "%02X%02X%02X", r, g, b)
}
