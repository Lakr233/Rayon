//
//  RDMachine.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/8.
//

import Foundation

public struct RDMachineGroup: Codable, Identifiable, Equatable {
    public typealias AssociatedType = RDMachine

    public var id = UUID()

    public private(set) var machines: [AssociatedType] = []
    public var sections: [String] {
        [String](Set<String>(
            machines.map(\.group)
        )).sorted()
    }

    public var count: Int {
        machines.count
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.machines == rhs.machines
    }

    public mutating func insert(_ value: AssociatedType) {
        guard value.isNotPlaceholder() else {
            return
        }
        if let index = machines.firstIndex(where: { $0.id == value.id }) {
            machines[index] = value
        } else {
            machines.append(value)
        }
    }

    public subscript(section: String) -> [AssociatedType] {
        machines.filter { $0.group == section }
    }

    public subscript(_ id: AssociatedType.ID) -> AssociatedType {
        get {
            machines.first(where: { $0.id == id }) ?? .init()
        }

        set(newValue) {
            if let index = machines.firstIndex(where: { $0.id == newValue.id }) {
                machines[index] = newValue
            } else {
                debugPrint("setting subscript found nil when sending value, did you forget to call insert?")
            }
        }
    }

    public mutating func delete(_ value: AssociatedType.ID) {
        let index = machines
            .firstIndex { $0.id == value }
        if let index = index {
            machines.remove(at: index)
        }
    }
}
