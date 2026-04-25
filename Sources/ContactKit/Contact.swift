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

public struct Contact: Equatable, Sendable {
    public let name: String
    public let emails: [ContactField]
    public let phones: [ContactField]
    public let company: String

    public init(name: String,
                emails: [ContactField],
                phones: [ContactField],
                company: String) {
        self.name    = name
        self.emails  = emails
        self.phones  = phones
        self.company = company
    }

}
