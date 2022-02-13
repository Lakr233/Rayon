//
//  RDIdentity.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import Foundation
import NSRemoteShell

struct RDIdentities: Codable, Identifiable {
    typealias AssociatedType = RDIdentity

    var id = UUID()

    var identities: [AssociatedType] = []

    var count: Int {
        identities.count
    }

    mutating func insert(_ value: AssociatedType) {
        if let index = identities.firstIndex(where: { $0.id == value.id }) {
            identities[index] = value
        } else {
            identities.append(value)
        }
    }

    subscript(_ id: AssociatedType.ID) -> AssociatedType {
        get {
            identities.first(where: { $0.id == id }) ?? .init()
        }

        set(newValue) {
            if let index = identities.firstIndex(where: { $0.id == newValue.id }) {
                identities[index] = newValue
            }
        }
    }
}

struct RDIdentity: Codable, Identifiable, Equatable {
    init(
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

    var id: UUID = .init()

    // generic authenticate filed required for ssh
    var username: String
    var password: String
    var privateKey: String
    var publicKey: String

    // application required
    var lastRecentUsed: Date
    var comment: String
    var group: String
    var authenticAutomatically: Bool

    // reserved for future use
    var attachment: [String: String]

    func shortDescription() -> String {
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

    func getKeyType() -> String {
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
        } else {
            return "Password"
        }
    }

    func callAuthenticationWith(remote: NSRemoteShell) {
        if privateKey.count > 0 || publicKey.count > 0 {
            remote.authenticate(with: username, andPublicKey: publicKey, andPrivateKey: privateKey, andPassword: password)
        } else {
            remote.authenticate(with: username, andPassword: password)
        }
        if remote.isAuthenicated {
            let date = Date()
            debugPrint("Identity \(id) was used to authentic session at \(date.formatted())")
            mainActor {
                RayonStore.shared.userIdentities[id].lastRecentUsed = date
            }
        }
    }
}
