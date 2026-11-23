// AppRegistration.swift
//
// Registers and unregisters the helper as a launchd agent through SMAppService. Must run from
// the app's own executable: SMAppService finds the agent plist in the calling process's bundle.
// Exit status is the contract with HelperClient: 0 registered, 2 turned off by the user, 1 failed.

import Foundation
import ServiceManagement

enum AppRegistration {
    static let plistName = "com.kenscott.get-clear.helper.plist"

    static func register() -> Int32 {
        let service = SMAppService.agent(plistName: plistName)
        if service.status != .enabled {
            do {
                try service.register()
            } catch {
                FileHandle.standardError.write(Data("Couldn't register Get Clear's helper: \(error.localizedDescription)\n".utf8))
            }
        }
        return exitStatus(for: service.status)
    }

    static func unregister() -> Int32 {
        let service = SMAppService.agent(plistName: plistName)
        guard service.status != .notRegistered, service.status != .notFound else { return 0 }
        do {
            try service.unregister()
            return 0
        } catch {
            FileHandle.standardError.write(Data("Couldn't unregister Get Clear's helper: \(error.localizedDescription)\n".utf8))
            return 1
        }
    }

    private static func exitStatus(for status: SMAppService.Status) -> Int32 {
        switch status {
        case .enabled:
            return 0
        case .requiresApproval:
            FileHandle.standardError.write(Data((
                "Get Clear's background helper is turned off. Turn it on in System Settings → General → "
                    + "Login Items & Extensions → Get Clear.\n"
            ).utf8))
            SMAppService.openSystemSettingsLoginItems()
            return 2
        default:
            return 1
        }
    }
}
