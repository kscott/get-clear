// Contact.swift
//
// Unified contact record type used across the Get Clear suite.

import Foundation

public struct ContactField: Equatable, Hashable, Sendable {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

public extension ContactField {
    static let defaultEmailLabel = "work"
    static let defaultPhoneLabel = "mobile"
}

public struct Contact: Equatable, Sendable {
    public let identifier: String
    public let name: String
    public let emails: [ContactField]
    public let phones: [ContactField]
    public let company: String

    public init(identifier: String,
                name: String,
                emails: [ContactField],
                phones: [ContactField],
                company: String) {
        self.identifier = identifier
        self.name       = name
        self.emails     = emails
        self.phones     = phones
        self.company    = company
    }

}
