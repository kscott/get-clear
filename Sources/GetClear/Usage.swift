// Usage.swift
// Prints the usage string for get-clear and exits.

import Foundation
import GetClearKit

func usage() -> Never {
    print("""
    \(versionString(tool: "get-clear", built: builtVersion, suite: suiteVersion)) — Your commitments, your contacts, your communications

    Usage:
      get-clear what [range]          # Everything across all tools
      get-clear recap [range]         # Where you showed up
      get-clear setup                 # Configure which calendars appear in recap
      get-clear update                # Install the latest version

    Feedback: https://github.com/kscott/get-clear/issues
    """)
    exit(0)
}
