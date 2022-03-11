//
//  RDMachine.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/8.
//

import Foundation

public struct RDMachine: Codable, Identifiable, Equatable {
    public init(id: UUID = UUID(),
                remoteAddress: String = "",
                remotePort: String = "",
                name: String = "",
                group: String = "",
                lastConnection: Date = .init(),
                lastBanner: String = "",
                comment: String = "",
                associatedIdentity: String? = nil,
                attachment: [String: String] = [:])
    {
        self.id = id
        self.remoteAddress = remoteAddress
        self.remotePort = remotePort
        self.name = name
        self.group = group
        self.lastConnection = lastConnection
        self.lastBanner = lastBanner
        self.comment = comment
        self.associatedIdentity = associatedIdentity
        self.attachment = attachment
    }

    public var id = UUID()
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    // generic authenticate filed required for ssh
    public var remoteAddress: String
    public var remotePort: String

    // application required
    public var name: String
    public var group: String
    public var lastConnection: Date
    public var lastBanner: String
    public var comment: String
    public var associatedIdentity: String?

    // reserved for future use
    public var attachment: [String: String]

    // convince

    public func isQualifiedForSearch(text: String) -> Bool {
        let searchText = text.lowercased()
        if remoteAddress.description.lowercased().contains(searchText) { return true }
        if remotePort.description.lowercased().contains(searchText) { return true }
        if name.description.lowercased().contains(searchText) { return true }
        if group.description.lowercased().contains(searchText) { return true }
        if lastBanner.description.lowercased().contains(searchText) { return true }
        if comment.description.lowercased().contains(searchText) { return true }
        return false
    }

    public func shortDescription(withComment: Bool = true) -> String {
        var build = name + " "
        if let aid = associatedIdentity,
           let uid = UUID(uuidString: aid)
        {
            let identity = RayonStore.shared.identityGroup[uid]
            if !identity.username.isEmpty {
                build += identity.username + "@"
            }
        }
        build += remoteAddress
        if remotePort != "22" {
            build += " -p " + remotePort
        }
        if withComment, !comment.isEmpty {
            build += " (" + comment + ")"
        }
        return build
    }

    public func isNotPlaceholder() -> Bool {
        remoteAddress.count > 0 && remotePort.count > 0
    }

    public func getCommand(insertLeadingSSH: Bool = true) -> String {
        var build = ""
        let leading = insertLeadingSSH ? "ssh " : ""
        if let id = associatedIdentity,
           let rid = UUID(uuidString: id)
        {
            let oid = RayonStore.shared.identityGroup[rid]
            if !oid.username.isEmpty {
                build = leading + "\(oid.username)@\(remoteAddress)"
            }
        }
        if build.isEmpty {
            build = leading + "\(remoteAddress)"
        }
        if remotePort != "22" {
            build += " -p " + remotePort
        }
        return build
    }
}
