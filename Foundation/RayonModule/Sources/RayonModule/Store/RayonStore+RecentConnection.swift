//
//  RayonStore.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/3/1.
//

import Foundation

public extension RayonStore {
    enum RecentConnection: Codable, Equatable, Identifiable {
        public var id: String {
            switch self {
            case let .command(command):
                return command.command
            case let .machine(machine):
                return machine.uuidString
            }
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }

        case command(command: SSHCommandReader)
        case machine(machine: RDMachine.ID)

        public var equivalentSSHCommand: String {
            switch self {
            case let .command(command):
                return command.command
            case let .machine(machineID):
                let machine = RayonStore.shared.machineGroup[machineID]
                guard let associatedIdentity = machine.associatedIdentity else {
                    return ""
                }
                guard let username = RayonStore.shared.identityGroup.identities.filter({ identity in
                    identity.id.uuidString == associatedIdentity
                }).first?.username else {
                    return ""
                }
                return "ssh \(username)@\(machine.remoteAddress) -p \(machine.remotePort)"
            }
        }
    }

    func cleanRecentIfNeeded() {
        let build = recentRecord
            .filter { record in
                switch record {
                case .command: return true
                case let .machine(machine): return machineGroup[machine].isNotPlaceholder()
                }
            }
        mainActor {
            self.recentRecord = build
        }
    }

    func storeRecentIfNeeded(from recent: RecentConnection) {
        guard storeRecent else {
            return
        }
        mainActor {
            for lookup in self.recentRecord where lookup == recent {
                return
            }
            self.recentRecord.insert(recent, at: 0)
            while self.recentRecord.count > self.maxRecentRecordCount {
                self.recentRecord.removeLast()
            }
        }
    }

    func storeRecentIfNeeded(from machine: RDMachine.ID) {
        storeRecentIfNeeded(from: .machine(machine: machine))
    }

    func storeRecentIfNeeded(from command: SSHCommandReader) {
        storeRecentIfNeeded(from: .command(command: command))
    }
}
