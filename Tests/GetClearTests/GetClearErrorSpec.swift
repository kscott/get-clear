// GetClearErrorSpec.swift
// Tests for GetClearError — error description.

@testable import GetClear
import Testing

@Suite("GetClearError.errorDescription")
struct GetClearErrorTests {
    @Test("returns the message verbatim")
    func returnsMessageVerbatim() {
        #expect(GetClearError("Unrecognised range: nonsense").errorDescription == "Unrecognised range: nonsense")
    }
}
