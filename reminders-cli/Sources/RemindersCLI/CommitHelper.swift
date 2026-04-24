// CommitHelper.swift
// Shared save/remove → log → print sequence used by all mutating reminder handlers.

import GetClearKit

func commitAndLog(
    _ action: () throws -> Void,
    cmd: String,
    desc: String,
    container: String,
    confirmation: String,
    failMessage: String = "Could not save"
) {
    do {
        try action()
        try? ActivityLog.write(tool: "reminders", cmd: cmd, desc: desc, container: container)
        print(confirmation)
    } catch {
        fail("\(failMessage): \(error.localizedDescription)")
    }
}
