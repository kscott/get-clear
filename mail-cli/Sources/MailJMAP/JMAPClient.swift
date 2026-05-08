// JMAPClient.swift
// JMAP HTTP client; MailClient conformance over Fastmail (or any JMAP server).

import Foundation
import MailLib

// MARK: - Value types

public struct JMAPSession: Sendable {
    public let apiUrl: String
    public let uploadUrl: String
    public let accountId: String
}

public struct JMAPBlob {
    public let blobId: String
    public let type: String
    public let name: String
    public let size: Int
}

// MARK: - URLSession delegate

/// Preserves the Authorization header across HTTP redirects.
private final class AuthRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let token: String
    init(token: String) {
        self.token = token
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void)
    {
        var r = request
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        completionHandler(r)
    }
}

// MARK: - Constants

private enum MailboxRole {
    static let drafts = "drafts"
    static let sent = "sent"
}


// MARK: - JMAPClient

/// A JMAP client bound to a single authenticated session.
public struct JMAPClient: MailClient {
    public let token: String
    public let session: JMAPSession

    // MARK: Connection

    /// Authenticate with a JMAP server and return a ready-to-use client.
    public static func connect(token: String,
                               discoveryURL: String = "https://api.fastmail.com/.well-known/jmap") async throws -> JMAPClient
    {
        var req = URLRequest(url: URL(string: discoveryURL)!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let delegate = AuthRedirectDelegate(token: token)
        let urlSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let (data, _) = try await urlSession.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let apiUrl = json["apiUrl"] as? String,
              let uploadUrl = json["uploadUrl"] as? String,
              let primaryAccts = json["primaryAccounts"] as? [String: String],
              let accountId = primaryAccts["urn:ietf:params:jmap:mail"]
        else {
            throw MailError.jmapError("Invalid JMAP session response")
        }
        return JMAPClient(token: token,
                          session: JMAPSession(apiUrl: apiUrl, uploadUrl: uploadUrl, accountId: accountId))
    }

    // MARK: MailClient — send

    public func send(_ email: OutboundEmail) async throws {
        async let blobsTask = uploadAll(email.attachmentPaths)
        let (draftsId, sentId) = try await findSendMailboxIds()
        let blobs = try await blobsTask
        let emailId = try await createEmail(email, blobs: blobs, draftsId: draftsId)
        try await submitEmail(emailId: emailId, identityId: email.from.id,
                              draftsId: draftsId, sentId: sentId)
    }

    public func saveDraft(_ email: OutboundEmail) async throws {
        let blobs = try await uploadAll(email.attachmentPaths)
        guard let draftsId = try await findMailboxId(role: MailboxRole.drafts) else {
            throw MailError.jmapError("Could not find Drafts mailbox")
        }
        _ = try await createEmail(email, blobs: blobs, draftsId: draftsId)
    }

    // MARK: MailClient — find

    public func find(query: String, limit: Int) async throws -> [EmailSummary] {
        let responses = try await post(methodCalls: [
            ["Email/query", [
                "accountId": session.accountId,
                "filter": ["text": query],
                "sort": [["property": "receivedAt", "isAscending": false]],
                "limit": limit
            ] as [String: Any], "a"],
            ["Email/get", [
                "accountId": session.accountId,
                "#ids": ["resultOf": "a", "name": "Email/query", "path": "/ids"],
                "properties": ["subject", "from", "receivedAt"]
            ] as [String: Any], "b"]
        ])
        let result = try methodResult("Email/get", from: responses)
        let emails = result["list"] as? [[String: Any]] ?? []
        return emails.map { obj in
            let subject = obj["subject"] as? String ?? "(no subject)"
            let from = (obj["from"] as? [[String: Any]])?.first.map { addr -> String in
                AddressEntry(name: addr["name"] as? String ?? "",
                             email: addr["email"] as? String ?? "").formatted
            } ?? ""
            let received = obj["receivedAt"] as? String ?? ""
            return EmailSummary(subject: subject, from: from, receivedAt: received)
        }
    }

    // MARK: MailClient — identities

    public func fetchIdentities() async throws -> [MailIdentity] {
        let responses = try await post(
            using: ["urn:ietf:params:jmap:core",
                    "urn:ietf:params:jmap:mail",
                    "urn:ietf:params:jmap:submission"],
            methodCalls: [
                ["Identity/get",
                 ["accountId": session.accountId, "ids": NSNull()] as [String: Any],
                 "a"]
            ]
        )
        let result = try methodResult("Identity/get", from: responses)
        let list = result["list"] as? [[String: Any]] ?? []
        let identities: [MailIdentity] = list.compactMap { obj in
            guard let id = obj["id"] as? String,
                  let email = obj["email"] as? String else { return nil }
            let name = obj["name"] as? String ?? ""
            return MailIdentity(id: id, email: email, name: name)
        }
        guard !identities.isEmpty else { throw MailError.jmapError("No identities found") }
        return identities
    }

    // MARK: Low-level JMAP

    /// Send a JMAP method call batch and return the raw response array.
    public func post(
        using caps: [String] = ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
        methodCalls: [[Any]]
    ) async throws -> [[Any]] {
        let body: [String: Any] = ["using": caps, "methodCalls": methodCalls]
        var req = URLRequest(url: URL(string: session.apiUrl)!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responses = json["methodResponses"] as? [[Any]]
        else {
            throw MailError.jmapError("Invalid JMAP response")
        }
        return responses
    }

    /// Extract a named method result from a response batch, or throw on error.
    public func methodResult(_ name: String, from responses: [[Any]]) throws -> [String: Any] {
        if let errResp = responses.first(where: { ($0[0] as? String) == "error" }),
           let errResult = errResp[1] as? [String: Any]
        {
            let desc = errResult["description"] as? String ?? errResult["type"] as? String ?? "unknown"
            throw MailError.jmapError(desc)
        }
        guard let resp = responses.first(where: { ($0[0] as? String) == name }),
              let result = resp[1] as? [String: Any]
        else {
            throw MailError.jmapError("\(name) response missing")
        }
        return result
    }

    /// Upload a file and return its blob descriptor.
    public func uploadAttachment(path: String) async throws -> JMAPBlob {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let mime = mimeType(for: path)
        let endpoint = session.uploadUrl
            .replacingOccurrences(of: "{accountId}", with: session.accountId)
        var req = URLRequest(url: URL(string: endpoint)!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(mime, forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        let delegate = AuthRedirectDelegate(token: token)
        let uploadSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let (respData, _) = try await uploadSession.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any],
              let blobId = json["blobId"] as? String
        else {
            throw MailError.jmapError("Upload failed for \(path)")
        }
        return JMAPBlob(blobId: blobId, type: mime, name: url.lastPathComponent, size: data.count)
    }

    /// Resolve a mailbox ID by its JMAP role (e.g. "drafts", "sent").
    public func findMailboxId(role: String) async throws -> String? {
        let responses = try await post(methodCalls: [
            ["Mailbox/get", ["accountId": session.accountId, "ids": NSNull()] as [String: Any], "a"]
        ])
        let result = try methodResult("Mailbox/get", from: responses)
        let mailboxes = result["list"] as? [[String: Any]] ?? []
        return mailboxes.first(where: {
            ($0["role"] as? String)?.lowercased() == role.lowercased()
        })?["id"] as? String
    }

    // MARK: Private helpers

    private func findSendMailboxIds() async throws -> (drafts: String, sent: String) {
        let responses = try await post(methodCalls: [
            ["Mailbox/get", ["accountId": session.accountId, "ids": NSNull()] as [String: Any], "a"]
        ])
        let result = try methodResult("Mailbox/get", from: responses)
        let mailboxes = result["list"] as? [[String: Any]] ?? []
        let find = { (role: String) -> String? in
            mailboxes.first(where: { ($0["role"] as? String)?.lowercased() == role })
                .flatMap { $0["id"] as? String }
        }
        guard let drafts = find(MailboxRole.drafts) else { throw MailError.jmapError("Could not find Drafts mailbox") }
        guard let sent = find(MailboxRole.sent) else { throw MailError.jmapError("Could not find Sent mailbox") }
        return (drafts: drafts, sent: sent)
    }

    private func uploadAll(_ paths: [String]) async throws -> [JMAPBlob] {
        try await withThrowingTaskGroup(of: JMAPBlob.self) { group in
            for path in paths {
                group.addTask { try await uploadAttachment(path: path) }
            }
            var blobs: [JMAPBlob] = []
            for try await blob in group {
                blobs.append(blob)
            }
            return blobs
        }
    }

    private func createEmail(_ email: OutboundEmail, blobs: [JMAPBlob], draftsId: String) async throws -> String {
        let bodyStructure: [String: Any]
        if blobs.isEmpty {
            bodyStructure = ["type": "text/plain", "partId": "1"]
        } else {
            let subParts: [[String: Any]] = [["type": "text/plain", "partId": "1"]] + blobs.map { blob in
                ["blobId": blob.blobId, "type": blob.type, "name": blob.name, "disposition": "attachment"]
            }
            bodyStructure = ["type": "multipart/mixed", "subParts": subParts]
        }
        var emailCreate: [String: Any] = [
            "mailboxIds": [draftsId: true],
            "keywords": ["$draft": true],
            "from": [["name": email.from.name, "email": email.from.email]],
            "to": email.to.map { ["name": $0.name, "email": $0.email] },
            "subject": email.subject,
            "bodyStructure": bodyStructure,
            "bodyValues": ["1": ["value": email.body]]
        ]
        if !email.cc.isEmpty {
            emailCreate["cc"] = email.cc.map { ["name": $0.name, "email": $0.email] }
        }
        let responses = try await post(
            using: ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail",
                    "urn:ietf:params:jmap:submission"],
            methodCalls: [
                ["Email/set", ["accountId": session.accountId,
                               "create": ["e1": emailCreate]] as [String: Any], "0"]
            ]
        )
        let result = try methodResult("Email/set", from: responses)
        if let notCreated = result["notCreated"] as? [String: Any], !notCreated.isEmpty {
            let desc = (notCreated["e1"] as? [String: Any])?["description"] as? String ?? "unknown"
            throw MailError.sendFailed(desc)
        }
        guard let created = result["created"] as? [String: Any],
              let emailObj = created["e1"] as? [String: Any],
              let emailId = emailObj["id"] as? String
        else {
            throw MailError.sendFailed("Email not created")
        }
        return emailId
    }

    private func submitEmail(emailId: String, identityId: String,
                             draftsId: String, sentId: String) async throws
    {
        let responses = try await post(
            using: ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail",
                    "urn:ietf:params:jmap:submission"],
            methodCalls: [
                ["EmailSubmission/set", [
                    "accountId": session.accountId,
                    "create": ["s1": ["emailId": emailId, "identityId": identityId]],
                    "onSuccessUpdateEmail": [
                        "#s1": [
                            "keywords/$draft": NSNull(),
                            "mailboxIds/\(draftsId)": NSNull(),
                            "mailboxIds/\(sentId)": true
                        ]
                    ]
                ] as [String: Any], "0"]
            ]
        )
        let result = try methodResult("EmailSubmission/set", from: responses)
        if let notCreated = result["notCreated"] as? [String: Any], !notCreated.isEmpty {
            let desc = (notCreated["s1"] as? [String: Any])?["description"] as? String ?? "unknown"
            throw MailError.sendFailed("Submission failed: \(desc)")
        }
    }
}
