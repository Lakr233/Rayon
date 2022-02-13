//
//  RDRemoteMachine.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/8.
//

import Foundation

struct RDRemoteMachines: Codable, Identifiable, Equatable {
    typealias AssociatedType = RDRemoteMachine

    var id = UUID()

    var machines: [AssociatedType] = []
    var sections: [String] {
        [String](Set<String>(
            machines.map(\.group)
        )).sorted()
    }

    var count: Int {
        machines.count
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.machines == rhs.machines
    }

    mutating func insert(_ value: AssociatedType) {
        if let index = machines.firstIndex(where: { $0.id == value.id }) {
            machines[index] = value
        } else {
            machines.append(value)
        }
    }

    subscript(section: String) -> [AssociatedType] {
        machines.filter { $0.group == section }
    }

    subscript(_ id: AssociatedType.ID) -> AssociatedType {
        get {
            machines.first(where: { $0.id == id }) ?? .init()
        }

        set(newValue) {
            if let index = machines.firstIndex(where: { $0.id == newValue.id }) {
                machines[index] = newValue
            }
        }
    }
}

struct RDRemoteMachine: Codable, Identifiable, Equatable {
    init(id: UUID = UUID(),
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

    var id = UUID()
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    // generic authenticate filed required for ssh
    var remoteAddress: String
    var remotePort: String

    // application required
    var name: String
    var group: String
    var lastConnection: Date
    var lastBanner: String
    var comment: String
    var associatedIdentity: String?

    // reserved for future use
    var attachment: [String: String]

    // convince

    func isQualifiedForSearch(text: String) -> Bool {
        let searchText = text.lowercased()
        if remoteAddress.description.lowercased().contains(searchText) { return true }
        if remotePort.description.lowercased().contains(searchText) { return true }
        if name.description.lowercased().contains(searchText) { return true }
        if group.description.lowercased().contains(searchText) { return true }
        if lastBanner.description.lowercased().contains(searchText) { return true }
        if comment.description.lowercased().contains(searchText) { return true }
        return false
    }

    func isNotPlaceholder() -> Bool {
        remoteAddress.count > 0 && remotePort.count > 0
    }
}

enum RDRemoteMachineRedactedLevel: Int {
    case none = 0
    case sensitive = 1
    case all = 2
}
