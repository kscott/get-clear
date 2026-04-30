// StoreFactory.swift
// Constructs the contact store for the mail-bin executable.

import ContactKit
import ContactStoreFactory

func makeStore() async -> any ContactStore {
    await ContactStoreFactory.makeContactStore()
}
