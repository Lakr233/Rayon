//
//  BatchSnippetExecContext.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/13.
//

import Combine
import NSRemoteShell

class BatchSnippetExecContext: ObservableObject {
    let snippet: RDSnippet
    let machines: [RDRemoteMachine.ID]
    let names: [RDRemoteMachine.ID: String]
    init(snippet: RDSnippet, machines: [RDRemoteMachine.ID]) {
        self.snippet = snippet
        self.machines = machines
        var buildNames: [RDRemoteMachine.ID: String] = [:]
        for machine in machines {
            // run this in main thread
            let object = RayonStore.shared.remoteMachines[machine]
            guard object.isNotPlaceholder() else {
                debugPrint("garbage machine found")
                receivedBuffer[machine] = "\r\n[*] Malformed Machine Info\r\n"
                continue
            }
            shellObjects[object.id] = NSRemoteShell()
                .setupConnectionHost(object.remoteAddress)
                .setupConnectionPort(NSNumber(value: Int(object.remotePort) ?? 0))
                .setupConnectionTimeout(6)
            shellContinue[object.id] = true
            if let identity = object.associatedIdentity,
               let rid = UUID(uuidString: identity)
            {
                let identityObject = RayonStore.shared.userIdentities[rid]
                if identityObject.username.count > 0 {
                    requiredIdentities[object.id] = identityObject
                }
            }
            buildNames[machine] = object.name
        }
        names = buildNames
        DispatchQueue.global().async {
            self.beingExecution()
        }
    }

    deinit {
        debugPrint("\(self) \(#function)")
    }

    private var completed: Bool = false
    private var shellObjects: [RDRemoteMachine.ID: NSRemoteShell] = [:]
    private var requiredIdentities: [RDRemoteMachine.ID: RDIdentity] = [:]
    private var shellContinue: [RDRemoteMachine.ID: Bool] = [:]
    private var receivedBuffer: [RDRemoteMachine.ID: String] = [:]
    private var completedMachines: [RDRemoteMachine.ID] = []
    private var bufferForTermId: [UUID: String] = [:]

    var safeAccessCompleted: Bool {
        accessLock.lock()
        let value = completed
        accessLock.unlock()
        return value
    }

    var safeAccessShellObjects: [RDRemoteMachine.ID: NSRemoteShell] {
        accessLock.lock()
        let value = shellObjects
        accessLock.unlock()
        return value
    }

    var safeAccessRequiredIdentities: [RDRemoteMachine.ID: RDIdentity] {
        accessLock.lock()
        let value = requiredIdentities
        accessLock.unlock()
        return value
    }

    var safeAccessShellContinue: [RDRemoteMachine.ID: Bool] {
        accessLock.lock()
        let value = shellContinue
        accessLock.unlock()
        return value
    }

    var safeAccessReceivedBuffer: [RDRemoteMachine.ID: String] {
        accessLock.lock()
        let value = receivedBuffer
        accessLock.unlock()
        return value
    }

    var safeAccessCompletedMachines: [RDRemoteMachine.ID] {
        accessLock.lock()
        let value = completedMachines
        accessLock.unlock()
        return value
    }

    let accessLock = NSLock()
    func safeAccess(on: () -> Void) {
        accessLock.lock()
        on()
        accessLock.unlock()
    }

    func beingExecution() {
        let queue = DispatchQueue(
            label: "wiki.qaq.rayon.exec.batch.\(snippet.name)",
            attributes: .concurrent
        )
        let machines = machines
        queue.async {
            let group = DispatchGroup()
            for machine in machines {
                group.enter()
                queue.async {
                    defer { group.leave() }
                    self.beginExec(on: machine)
                }
            }
            group.wait()
            self.safeAccess {
                self.completed = true
            }
        }
    }

    func requestBuffer(for terminalId: UUID, machine: UUID) -> String {
        accessLock.lock()
        let buffer = receivedBuffer[machine, default: ""]
        let current = bufferForTermId[terminalId, default: ""]
        var write = ""
        if buffer.count > current.count {
            write = buffer
            write.removeFirst(current.count)
        }
        bufferForTermId[terminalId] = buffer
        accessLock.unlock()
        return write
    }

    func beginExec(on machine: RDRemoteMachine.ID) {
        defer {
            debugPrint("execution subroutine completed for machine: \(machine)")
            safeAccess {
                self.completedMachines.append(machine)
            }
        }
        guard let shell = shellObjects[machine] else {
            // our error not user's
            debugPrint("missing shell for machine: \(machine)")
            return
        }
        defer { shell.requestDisconnectAndWait() }
        shell.requestConnectAndWait()
        guard shell.isConnected else {
            debugPrint("failed to connect to remote machine: \(machine)")
            safeAccess {
                self.receivedBuffer[machine, default: ""].append("\r\n[E] Failed to connect to remote machine: \(machine)\r\n")
            }
            return
        }
        guard let identity = requiredIdentities[machine] else {
            debugPrint("auto auth is not supported on batch exec")
            safeAccess {
                self.receivedBuffer[machine, default: ""].append("\r\n[E] Auto auth is not supported on batch exec\r\n")
            }
            return
        }
        identity.callAuthenticationWith(remote: shell)
        guard shell.isConnected, shell.isAuthenicated else {
            debugPrint("auth failed for machine: \(machine)")
            safeAccess {
                self.receivedBuffer[machine, default: ""].append("\r\n[E] Failed to authenticate for machine: \(machine)\r\n")
            }
            return
        }
        shell.executeRemote(
            snippet.code,
            withExecTimeout: 0
        ) { output in
            // because the output is picked up by xterm, we need to replace \n to \r\n
            let output = output
                .replacingOccurrences(of: "\n", with: "\r\n") // \n -> \r\n, \r\n -> \r\r\n
                .replacingOccurrences(of: "\r\r\n", with: "\r\n") // \r\r -> \n
            self.safeAccess {
                self.receivedBuffer[machine, default: ""].append(output)
            }
        } withContinuationHandler: {
            let sem = DispatchSemaphore(value: 0)
            var get = false
            self.safeAccess {
                defer { sem.signal() }
                get = self.shellContinue[machine, default: false]
            }
            sem.wait()
            return get
        }
        safeAccess {
            self.shellObjects.removeValue(forKey: machine)
            self.receivedBuffer[machine, default: ""].append("\r\n[*] Execution completed\r\n")
        }
    }
}
