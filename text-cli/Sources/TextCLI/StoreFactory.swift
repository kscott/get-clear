// StoreFactory.swift

import TextMessages
import TextLib

func makeMessageSender() -> any MessageSender {
    AppleMessageSender()
}
