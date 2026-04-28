import GetClearKit

public struct ContactChanges: Equatable {
    public let email: ValueChange<String>
    public let phone: ValueChange<String>
    public let company: ValueChange<String>

    public init(email: ValueChange<String> = .unchanged,
                phone: ValueChange<String> = .unchanged,
                company: ValueChange<String> = .unchanged) {
        self.email   = email
        self.phone   = phone
        self.company = company
    }
}
