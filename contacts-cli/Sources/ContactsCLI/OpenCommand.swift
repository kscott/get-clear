// OpenCommand.swift
//
// Opens the Contacts app.

import AppKit

func handleOpen(semaphore: DispatchSemaphore) {
    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Contacts.app"))
    semaphore.signal()
}
