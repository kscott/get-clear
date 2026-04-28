public enum ValueChange<T: Equatable>: Equatable {
    case unchanged
    case cleared
    case added(T)
    case removed(T)
    case replaced(from: T, to: T)
}
