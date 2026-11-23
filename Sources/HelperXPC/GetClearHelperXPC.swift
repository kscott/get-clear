// GetClearHelperXPC.swift
//
// The one @objc method both sides of the helper connection speak, and the names and signing
// requirement they share (spec 018, contracts/helper-protocol.md). The method never changes:
// new store methods add request cases, not @objc methods.

import Foundation

@objc protocol GetClearHelperXPC {
    /// `envelope` is a JSON HelperEnvelope; the reply is a JSON HelperReply.
    func perform(_ envelope: Data, reply: @escaping (Data) -> Void)
}

public enum HelperXPC {
    /// The helper's Mach service, and its launchd label.
    public static let machServiceName = "com.kenscott.get-clear.helper"
    /// Each side accepts only code signed by Get Clear's developer (FR-008). The Team ID is
    /// quoted; unquoted, it traps inside setCodeSigningRequirement.
    public static let peerRequirement = "anchor apple generic and certificate leaf[subject.OU] = \"6Q96Q79QN8\""
}
