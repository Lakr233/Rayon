//
//  RDSnippet.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/10.
//

import Foundation

public struct RDSnippetGroup: Codable, Identifiable, Equatable {
    public typealias AssociatedType = RDSnippet

    public var id = UUID()

    public private(set) var snippets: [AssociatedType] = []
    public var sections: [String] {
        [String](Set<String>(
            snippets.map(\.group)
        )).sorted()
    }

    public var count: Int {
        snippets.count
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.snippets == rhs.snippets
    }

    public mutating func insert(_ value: AssociatedType) {
        guard !value.name.isEmpty else { return }
        if let index = snippets.firstIndex(where: { $0.id == value.id }) {
            snippets[index] = value
        } else {
            snippets.append(value)
        }
    }

    public subscript(section: String) -> [AssociatedType] {
        snippets.filter { $0.group == section }
    }

    public subscript(_ id: AssociatedType.ID) -> AssociatedType {
        get {
            snippets.first(where: { $0.id == id }) ?? .init()
        }

        set(newValue) {
            if let index = snippets.firstIndex(where: { $0.id == newValue.id }) {
                snippets[index] = newValue
            } else {
                debugPrint("setting subscript found nil when sending value, did you forget to call insert?")
            }
        }
    }

    public mutating func delete(_ value: AssociatedType.ID) {
        let index = snippets
            .firstIndex { $0.id == value }
        if let index = index {
            snippets.remove(at: index)
        }
    }
}
