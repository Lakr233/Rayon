//
//  RDIdentity.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import Foundation
import NSRemoteShell

public struct RDIdentity: Codable, Identifiable, Equatable {
    public init(
        id: UUID = .init(),
        username: String = "",
        password: String = "",
        privateKey: String = "",
        publicKey: String = "",
        lastRecentUsed: Date = .init(),
        comment: String = "",
        group: String = "",
        authenticAutomatically: Bool = true,
        attachment: [String: String] = [:]
    ) {
        self.id = id
        self.username = username
        self.password = password
        self.privateKey = privateKey
        self.publicKey = publicKey
        self.lastRecentUsed = lastRecentUsed
        self.comment = comment
        self.group = group
        self.authenticAutomatically = authenticAutomatically
        self.attachment = attachment
    }

    public var id = UUID()

    // generic authenticate filed required for ssh
    public var username: String
    public var password: String
    public var privateKey: String
    public var publicKey: String

    // application required
    public var lastRecentUsed: Date
    public var comment: String
    public var group: String
    public var authenticAutomatically: Bool

    // reserved for future use
    public var attachment: [String: String]

    public func shortDescription() -> String {
        guard username.count > 0 else {
            return "Unknown Error"
        }
        var build = "User \(username) with \(getKeyType())"
        if group.count > 0 {
            build += " Group<\(group)>"
        }
        if comment.count > 0 {
            build += " (\(comment))"
        }
        return build
    }

    public func getKeyType() -> String {
        if privateKey.count > 0, publicKey.count > 0 {
            if password.count > 0 {
                return "Key Pair"
            } else {
                return "Plain Key Pair"
            }
        } else if privateKey.count > 0 {
            if password.count > 0 {
                return "Private Key"
            } else {
                return "Plain Private Key"
            }
        } else if publicKey.count > 0 {
            return "Unknown Key"
        } else if password.count > 0 {
            return "Password"
        } else {
            return "Username Only"
        }
    }

    public func callAuthenticationWith(remote: NSRemoteShell) {
        if privateKey.count > 0 || publicKey.count > 0 {
            remote.authenticate(with: username, andPublicKey: publicKey, andPrivateKey: privateKey, andPassword: password)
        } else {
            remote.authenticate(with: username, andPassword: password)
        }
        if remote.isAuthenicated {
            let date = Date()
            let fmt = DateFormatter()
            fmt.dateStyle = .full
            fmt.timeStyle = .full
            debugPrint("Identity \(id) was used to authentic session at \(fmt.string(from: date))")
            mainActor {
                RayonStore.shared.identityGroup[id].lastRecentUsed = date
            }
        }
    }
}
