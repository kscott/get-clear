// StoreFactory.swift
// Constructs the concrete MessageSender for use in the text-bin executable.

import ContactStoreFactory
import TextLib
import TextMessages

func makeMessageSender() async -> any MessageSender {
    await AppleMessageSender(contacts: makeContactStore())
}
