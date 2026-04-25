// StoreFactory.swift
// Constructs the concrete MessageSender for use in the text-bin executable.

import TextLib
import TextMessages
import ContactStoreFactory

func makeMessageSender() async -> any MessageSender {
    AppleMessageSender(contacts: await makeContactStore())
}
