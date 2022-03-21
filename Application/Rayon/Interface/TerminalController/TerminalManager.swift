//
//  TerminalManager.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/3/10.
//

import Combine
import Foundation
import RayonModule

class TerminalManager: ObservableObject {
    static let shared = TerminalManager()
    private init() {}

    @Published var sessionContexts: [Context] = []

    func createSession(withMachineObject machine: RDMachine, force: Bool = false) {
        let index = sessionContexts.firstIndex { $0.machine.id == machine.id }
        if index != nil, !force {
            UIBridge.requiresConfirmation(message: "A session for \(machine.name) is already in place, are you sure to open another?") { confirmed in
                if confirmed {
                    self.createSession(withMachineObject: machine, force: true)
                }
            }
            return
        }
        let context = Context(machine: machine)
        sessionContexts.append(context)
        RayonStore.shared.storeRecentIfNeeded(from: machine.id)
    }

    func createSession(withMachineID machineId: RDMachine.ID) {
        let machine = RayonStore.shared.machineGroup[machineId]
        guard machine.isNotPlaceholder() else {
            UIBridge.presentError(with: "Malformed application memory")
            return
        }
        createSession(withMachineObject: machine)
    }

    func createSession(withCommand command: SSHCommandReader) {
        let context = Context(command: command)
        sessionContexts.append(context)
        RayonStore.shared.storeRecentIfNeeded(from: command)
    }

    func sessionExists(for machine: RDMachine.ID) -> Bool {
        for context in sessionContexts where context.machine.id == machine {
            return true
        }
        return false
    }

    func sessionAlive(forMachine machineId: RDMachine.ID) -> Bool {
        !(
            sessionContexts
                .first { $0.machine.id == machineId }?
                .closed ?? true
        )
    }

    func sessionAlive(forContext contextId: Context.ID) -> Bool {
        !(
            sessionContexts
                .first { $0.id == contextId }?
                .closed ?? true
        )
    }

    func closeSession(withMachineID machineId: RDMachine.ID) {
        let index = sessionContexts.firstIndex { $0.machine.id == machineId }
        if let index = index {
            let context = sessionContexts.remove(at: index)
            context.processShutdown()
            context.shell.destroyPermanently()
        }
    }

    func closeSession(withContextID contextId: Context.ID) {
        let index = sessionContexts.firstIndex { $0.id == contextId }
        if let index = index {
            let context = sessionContexts.remove(at: index)
            context.processShutdown()
            context.shell.destroyPermanently()
        }
    }

    func closeAll() {
        for context in sessionContexts {
            context.processShutdown()
            context.shell.destroyPermanently()
        }
        sessionContexts = []
    }
}
