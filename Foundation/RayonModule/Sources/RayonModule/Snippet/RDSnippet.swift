//
//  RDSnippet.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/10.
//

import Foundation

public struct RDSnippet: Codable, Identifiable, Equatable {
    public init(
        id: UUID = UUID(),
        name: String = "",
        group: String = "",
        code: String = "",
        comment: String = "",
        attachment: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.group = group
        self.code = code
        self.comment = comment
        self.attachment = attachment
    }

    public var id: UUID

    public var name: String
    public var group: String
    public var code: String
    public var comment: String

    public var attachment: [String: String]

    public func isQualifiedForSearch(text: String) -> Bool {
        let searchText = text.lowercased()
        if name.lowercased().contains(searchText) {
            return true
        }
        if group.lowercased().contains(searchText) {
            return true
        }
        if code.lowercased().contains(searchText) {
            return true
        }
        if comment.lowercased().contains(searchText) {
            return true
        }
        return false
    }

    private enum AttachmentKey: String {
        case sfAvatar
    }

    public mutating func setSFAvatar(sfSymbol name: String) {
        attachment[AttachmentKey.sfAvatar.rawValue] = name
    }

    public mutating func clearSFAvatar() {
        attachment.removeValue(forKey: AttachmentKey.sfAvatar.rawValue)
    }

    public func getSFAvatar() -> String {
        if let avatar = attachment[AttachmentKey.sfAvatar.rawValue],
           !avatar.isEmpty
        {
            return avatar
        }
        return "arrow.right.doc.on.clipboard"
    }
}
