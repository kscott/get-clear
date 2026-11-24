// ExecutablePath.swift
//
// The running command's own path with symlinks resolved, so `/usr/local/bin/reminders` arrives
// as the path inside Get Clear.app. Feeds AccessRoute (spec 018).

import Darwin
import Foundation

public func resolvedExecutableURL() -> URL {
    var size: UInt32 = 0
    _NSGetExecutablePath(nil, &size)
    var path = [CChar](repeating: 0, count: Int(size))
    _NSGetExecutablePath(&path, &size)
    var resolved = [CChar](repeating: 0, count: Int(PATH_MAX))
    guard realpath(path, &resolved) != nil else {
        return URL(fileURLWithPath: String(cString: path))
    }
    return URL(fileURLWithPath: String(cString: resolved))
}

public extension AccessRoute {
    /// The route for the command that is running right now.
    static var current: AccessRoute {
        decide(resolvedExecutable: resolvedExecutableURL())
    }
}
