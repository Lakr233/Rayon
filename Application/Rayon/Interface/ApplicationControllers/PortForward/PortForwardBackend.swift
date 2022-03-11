//
//  PortForwardBackend.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/3/11.
//

import Combine
import NSRemoteShell
import RayonModule

class PortForwardBackend: ObservableObject {
    static let shared = PortForwardBackend()

    private init() {}

    @Published var container = [Context]()
    struct Context: Identifiable {
        var id = UUID()
        let info: RDPortForward
        let machine: RDMachine
        let shell: NSRemoteShell
    }

    @Published var lastHint: [Context.ID: String] = [:]

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
    }

    func putHint(for pid: RDPortForward.ID, with: String) {
        mainActor {
            self.lastHint[pid] = with
        }
    }

    func beginLifecycle(for context: Context) {
        DispatchQueue.global().async {
            self.putHint(for: context.info.id, with: "awaiting connect")
            context.shell
                .setupConnectionHost(context.machine.remoteAddress)
                .setupConnectionPort(NSNumber(value: Int(context.machine.remotePort) ?? 0))
                .setupConnectionTimeout(RayonStore.shared.timeoutNumber)
                .requestConnectAndWait()
            guard context.shell.isConnected else {
                self.putHint(for: context.info.id, with: "failed connect")
                return
            }
            guard let str = context.machine.associatedIdentity,
                  let aid = UUID(uuidString: str)
            else {
                self.putHint(for: context.info.id, with: "failed authenticate")
                return
            }
            let identity = RayonStore.shared.identityGroup[aid]
            guard !identity.username.isEmpty else {
                self.putHint(for: context.info.id, with: "failed authenticate")
                return
            }
            identity.callAuthenticationWith(remote: context.shell)
            guard context.shell.isAuthenicated else {
                self.putHint(for: context.info.id, with: "failed authenticate")
                return
            }
            self.putHint(for: context.info.id, with: "forward running")
            switch context.info.forwardOrientation {
            case .listenRemote:
                context.shell.createPortForward(
                    withRemotePort: NSNumber(value: context.info.bindPort),
                    withForwardTargetHost: context.info.targetHost,
                    withForwardTargetPort: NSNumber(value: context.info.targetPort)
                ) {
                    true // we are using shell.disconnect for shutdown
                }
            case .listenLocal:
                context.shell.createPortForward(
                    withLocalPort: NSNumber(value: context.info.bindPort),
                    withForwardTargetHost: context.info.targetHost,
                    withForwardTargetPort: NSNumber(value: context.info.targetPort)
                ) {
                    true // we are using shell.disconnect for shutdown
                }
            }
            self.putHint(for: context.info.id, with: "forward stopped")
        }
    }

    func sessionExists(withPortForwardID pid: RDPortForward.ID) -> Bool {
        container.first { $0.info.id == pid } != nil
    }

    func endSession(withPortForwardID pid: RDPortForward.ID) {
        let index = container.firstIndex { $0.info.id == pid }
        putHint(for: pid, with: "terminating")
        if let index = index {
            let context = container.remove(at: index)
            DispatchQueue.global().async {
                context.shell.requestDisconnectAndWait()
            }
        }
    }
}
