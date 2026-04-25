// StoreFactory.swift

import TextLib
import TextMessages
import ContactStoreFactory

func makeMessageSender() async -> any MessageSender {
    AppleMessageSender(contacts: await makeContactStore())
}
