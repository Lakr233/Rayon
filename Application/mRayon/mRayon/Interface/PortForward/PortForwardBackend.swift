//
//  PortForwardBackend.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/14.
//

import Combine
import Foundation
import NSRemoteShell
import RayonModule

class PortForwardBackend: ObservableObject {
    static let shared = PortForwardBackend()

    private init() {}

    @Published var container = [Context]()
    class Context: ObservableObject, Identifiable {
        var id = UUID()
        let info: RDPortForward
        let machine: RDMachine
        let shell: NSRemoteShell

        @Published var closed: Bool = false

        init(id: UUID = UUID(), info: RDPortForward, machine: RDMachine, shell: NSRemoteShell) {
            self.id = id
            self.info = info
            self.machine = machine
            self.shell = shell
        }

        func terminate() {
            DispatchQueue.global().async {
                self.shell.requestDisconnectAndWait()
                self.shell.destroyPermanently()
            }
            mainActor {
                self.closed = true
            }
        }

        func contextRun() {
            DispatchQueue.global().async {
                while !self.closed {
                    self.contextRunRound()
                    sleep(3)
                }
                self.putHint("terminated")
            }
        }

        func contextRunRound() {
            putHint("awaiting connect")
            shell
                .setupConnectionHost(machine.remoteAddress)
                .setupConnectionPort(NSNumber(value: Int(machine.remotePort) ?? 0))
                .setupConnectionTimeout(RayonStore.shared.timeoutNumber)
                .requestConnectAndWait()
            guard shell.isConnected else {
                putHint("failed connect")
                return
            }
            guard let str = machine.associatedIdentity,
                  let aid = UUID(uuidString: str)
            else {
                putHint("failed authenticate")
                return
            }
            let identity = RayonStore.shared.identityGroup[aid]
            guard !identity.username.isEmpty else {
                putHint("failed authenticate")
                return
            }
            identity.callAuthenticationWith(remote: shell)
            guard shell.isAuthenicated else {
                putHint("failed authenticate")
                return
            }
            putHint("opening channel")
            switch info.forwardOrientation {
            case .listenRemote:
                shell.createPortForward(
                    withRemotePort: NSNumber(value: info.bindPort),
                    withForwardTargetHost: info.targetHost,
                    withForwardTargetPort: NSNumber(value: info.targetPort)
                ) {
                    self.putHint("forward running")
                } withContinuationHandler: {
                    true // we are using shell.disconnect for shutdown
                }
            case .listenLocal:
                shell.createPortForward(
                    withLocalPort: NSNumber(value: info.bindPort),
                    withForwardTargetHost: info.targetHost,
                    withForwardTargetPort: NSNumber(value: info.targetPort)
                ) {
                    self.putHint("forward running")
                } withContinuationHandler: {
                    true // we are using shell.disconnect for shutdown
                }
            }
            putHint("forward stopped")
        }

        func putHint(_ with: String) {
            mainActor {
                PortForwardBackend.shared.lastHint[self.info.id] = with
            }
        }
    }

    @Published var lastHint = [RDPortForward.ID: String]()

    func createSession(withPortForwardID pid: RDPortForward.ID) {
        if sessionExists(withPortForwardID: pid) {
            // multiple start
            return
        }
        let portFwd = RayonStore.shared.portForwardGroup[pid]
        guard portFwd.isValid(),
              let mid = portFwd.usingMachine
        else {
            UIBridge.presentError(with: "Invalid Info")
            return
        }
        let machine = RayonStore.shared.machineGroup[mid]
        guard machine.isNotPlaceholder() else {
            UIBridge.presentError(with: "Invalid Info")
            return
        }
        let context = Context(
            info: portFwd,
            machine: machine,
            shell: .init()
        )
        container.append(context)
        beginLifecycle(for: context)
        UIBridge.presentSuccess(with: "Forward Created")
    }

    private func beginLifecycle(for context: Context) {
        context.contextRun()
    }

    func sessionExists(withPortForwardID pid: RDPortForward.ID) -> Bool {
        container.first { $0.info.id == pid } != nil
    }

    func sessionContext(withPortForwardID pid: RDPortForward.ID) -> Context? {
        container.first { $0.info.id == pid }
    }

    func endSession(withPortForwardID pid: RDPortForward.ID) {
        let index = container.firstIndex { $0.info.id == pid }
        if let index = index {
            let context = container.remove(at: index)
            DispatchQueue.global().async {
                context.terminate()
            }
        }
    }
}
