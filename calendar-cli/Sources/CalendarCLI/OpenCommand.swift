// OpenCommand.swift
//
// Opens the Calendar app via NSWorkspace.

import AppKit
import Foundation

func handleOpen(semaphore: DispatchSemaphore) {
    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
    semaphore.signal()
}
