// StoreFactory.swift
//
// Constructs the MessageSender for the text-bin executable (spec 018). Inside Get Clear.app, the
// helper sends (and looks up contacts), so both permissions belong to Get Clear. Anywhere else
// (a development build), the command sends directly, as before.

import ContactStoreFactory
import GetClearKit
import HelperXPC
import TextLib
import TextMessages

func makeMessageSender() async -> any MessageSender {
    switch AccessRoute.current {
    case let .helper(appURL):
        RemoteMessageSender(transport: HelperClient.transport(appURL: appURL), appVersion: suiteVersion)
    case .direct:
        await AppleMessageSender(contacts: makeContactStore())
    }
}
