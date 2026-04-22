// OpenCommand.swift
//
// Opens the Reminders app via NSWorkspace.

import AppKit

func handleOpen() async {
    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Reminders.app"))
}
