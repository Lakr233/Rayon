//
//  File.swift
//
//
//  Created by Lakr Aream on 2022/3/10.
//

import Foundation

public struct RDPortForwardGroup: Codable, Identifiable, Equatable {
    public typealias AssociatedType = RDPortForward

    public var id = UUID()

    public private(set) var forwards: [AssociatedType] = []

    public var count: Int {
        forwards.count
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    public mutating func insert(_ value: AssociatedType) {
        guard !value.name.isEmpty else { return }
        if let index = forwards.firstIndex(where: { $0.id == value.id }) {
            forwards[index] = value
        } else {
            forwards.append(value)
        }
    }

    public subscript(_ id: AssociatedType.ID) -> AssociatedType {
        get {
            forwards.first(where: { $0.id == id }) ?? .init()
        }

        set(newValue) {
            if let index = forwards.firstIndex(where: { $0.id == newValue.id }) {
                forwards[index] = newValue
            } else {
                debugPrint("setting subscript found nil when sending value, did you forget to call insert?")
            }
        }
    }

    public mutating func delete(_ value: AssociatedType.ID) {
        let index = forwards
            .firstIndex { $0.id == value }
        if let index = index {
            forwards.remove(at: index)
        }
    }
}
