//
//  RDSnippet.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/10.
//

import Foundation

struct RDSnippets: Codable, Identifiable, Equatable {
    typealias AssociatedType = RDSnippet

    var id = UUID()

    var snippets: [AssociatedType] = []
    var sections: [String] {
        [String](Set<String>(
            snippets.map(\.group)
        )).sorted()
    }

    var count: Int {
        snippets.count
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.snippets == rhs.snippets
    }

    mutating func insert(_ value: AssociatedType) {
        if let index = snippets.firstIndex(where: { $0.id == value.id }) {
            snippets[index] = value
        } else {
            snippets.append(value)
        }
    }

    subscript(section: String) -> [AssociatedType] {
        snippets.filter { $0.group == section }
    }

    subscript(_ id: AssociatedType.ID) -> AssociatedType {
        get {
            snippets.first(where: { $0.id == id }) ?? .init()
        }

        set(newValue) {
            if let index = snippets.firstIndex(where: { $0.id == newValue.id }) {
                snippets[index] = newValue
            }
        }
    }
}

struct RDSnippet: Codable, Identifiable, Equatable {
    init(
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

    var id: UUID

    var name: String
    var group: String
    var code: String
    var comment: String

    var attachment: [String: String]

    func isQualifiedForSearch(text: String) -> Bool {
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
}
