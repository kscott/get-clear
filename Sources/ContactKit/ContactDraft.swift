public struct ContactDraft: Equatable, Sendable {
    public let name: String
    public let emails: [String]
    public let phones: [String]
    public let company: String?

    public init(name: String,
                emails: [String] = [],
                phones: [String] = [],
                company: String? = nil) {
        self.name    = name
        self.emails  = emails
        self.phones  = phones
        self.company = company
    }
}
