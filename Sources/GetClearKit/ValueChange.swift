public enum ValueChange<T: Equatable>: Equatable {
    case unchanged
    case cleared
    case added(T)
    case removed(T)
    case replaced(from: T, to: T)
}

/// Change structs cross the helper connection as JSON (spec 018).
extension ValueChange: Codable where T: Codable {}

extension ValueChange: Sendable where T: Sendable {}
