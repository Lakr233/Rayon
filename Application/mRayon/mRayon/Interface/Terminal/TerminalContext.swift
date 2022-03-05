//
//  TerminalContext.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/3.
//

import Foundation
import NSRemoteShell
import RayonModule
import SwiftUI
import UIKit
import XTerminalUI

class TerminalContext: ObservableObject, Identifiable, Equatable {
    var id: UUID = .init()
    var title: String = ""

    enum RemoteType {
        case machine
        case command
    }

    let remoteType: RemoteType

    let machine: RDMachine
    let command: SSHCommandReader?
    var shell: NSRemoteShell

    // MARK: - SHELL CONTEXT

    var closed: Bool { !continueDecision }

    @Published var interfaceToken: UUID = .init()
    @Published var interfaceDisabled: Bool = false

    static let defaultTerminalSize = CGSize(width: 80, height: 40)

    var termianlSize: CGSize = defaultTerminalSize {
        didSet {
            shell.explicitRequestStatusPickup()
        }
    }

    private var _dataBuffer: String = ""
    private var bufferAccessLock = NSLock()

    func getBuffer() -> String {
        bufferAccessLock.lock()
        defer { bufferAccessLock.unlock() }
        let copy = _dataBuffer
        _dataBuffer = ""
        return copy
    }

    func insertBuffer(_ str: String) {
        bufferAccessLock.lock()
        defer { bufferAccessLock.unlock() }
        _dataBuffer += str
        TerminalContext.queue.async { [weak self] in
            self?.shell.explicitRequestStatusPickup()
        }
    }

    var continueDecision: Bool = true {
        didSet {
            interfaceDisabled = !continueDecision
        }
    }

    // MARK: SHELL CONTEXT -

    let termInterface: STerminalView = .init()

    private static let queue = DispatchQueue(
        label: "wiki.qaq.terminal",
        attributes: .concurrent
    )

    init(machine: RDMachine) {
        self.machine = machine
        command = nil
        remoteType = .machine
        title = machine.name
        shell = .init()
            .setupConnectionHost(machine.remoteAddress)
            .setupConnectionPort(NSNumber(value: Int(machine.remotePort) ?? 0))
            .setupConnectionTimeout(6)
        TerminalContext.queue.async {
            self.processBootstrap()
        }
    }

    init(command: SSHCommandReader) {
        machine = RDMachine(
            remoteAddress: command.remoteAddress,
            remotePort: command.remotePort,
            name: command.remoteAddress,
            group: "SSHCommandReader",
            associatedIdentity: nil
        )
        self.command = command
        title = command.command
        remoteType = .machine
        shell = .init()
            .setupConnectionHost(machine.remoteAddress)
            .setupConnectionPort(NSNumber(value: Int(machine.remotePort) ?? 0))
            .setupConnectionTimeout(6)
        TerminalContext.queue.async {
            self.processBootstrap()
        }
    }

    static func == (lhs: TerminalContext, rhs: TerminalContext) -> Bool {
        lhs.id == rhs.id
    }

    func processBootstrap() {
        debugPrint("\(self) \(#function) \(machine.id)")
        // enter loop

        termInterface
            .setupBellChain {
                debugPrint("terminal bell")
            }
            .setupBufferChain { [weak self] buffer in
                self?.insertBuffer(buffer)
            }

        var alertRef: UIAlertController?
        defer { mainActor { alertRef?.dismiss(animated: true, completion: nil) } }

        mainActor {
            let alert = UIAlertController(
                title: "⏳",
                message: "Creating terminal connection...",
                preferredStyle: .alert
            )
            alertRef = alert
            UIWindow.shutUpKeyWindow?.topMostViewController?.present(alert, animated: true, completion: nil)
        }

        shell.requestConnectAndWait()

        guard shell.isConnected else {
            mainActor {
                alertRef?.dismiss(animated: true, completion: nil)
            }
            mainActor(delay: 0.5) {
                UIBridge.presentError(with: "Failed to create connection")
                TerminalManager.shared.end(for: self.id)
            }
            return
        }

        if let rid = machine.associatedIdentity {
            guard let uid = UUID(uuidString: rid) else {
                UIBridge.presentError(with: "Malformed machine data")
                TerminalManager.shared.end(for: id)
                return
            }
            let identity = RayonStore.shared.identityGroup[uid]
            guard !identity.username.isEmpty else {
                UIBridge.presentError(with: "Malformed identity data")
                TerminalManager.shared.end(for: id)
                return
            }
            identity.callAuthenticationWith(remote: shell)
        } else {
            var previousUsername: String?
            for identity in RayonStore.shared.identityGroupForAutoAuth {
                if let prev = previousUsername, prev != identity.username {
                    shell.requestDisconnectAndWait()
                    shell.requestConnectAndWait()
                }
                previousUsername = identity.username
                identity.callAuthenticationWith(remote: shell)
                if shell.isConnected, shell.isAuthenicated {
                    break
                }
            }
            if !shell.isAuthenicated,
               let identity = RayonUtil.selectIdentity()
            {
                RayonStore.shared
                    .identityGroup[identity]
                    .callAuthenticationWith(remote: shell)
            }
        }

        mainActor {
            alertRef?.dismiss(animated: true, completion: nil)
            alertRef = nil
        }

        guard shell.isConnected, shell.isAuthenicated else {
            UIBridge.presentError(with: "Failed to authenticate connection", delay: 1)
            TerminalManager.shared.end(for: id)
            return
        }

        mainActor {
            guard self.remoteType == .machine else {
                return
            }
            var read = RayonStore.shared.machineGroup[self.machine.id]
            if read.isNotPlaceholder() {
                read.lastBanner = self.shell.remoteBanner ?? "No Banner"
                RayonStore.shared.machineGroup[self.machine.id] = read
            }
        }

        termInterface.write("[*] Creating Connection\r\n\r\n")

        mainActor(delay: 1) {
            guard RayonStore.shared.openInterfaceAutomatically else { return }
            let host = UIHostingController(
                rootView: DefaultPresent(context: self)
            )
            host.isModalInPresentation = true
            host.modalTransitionStyle = .coverVertical
            host.modalPresentationStyle = .formSheet
            UIWindow.shutUpKeyWindow?
                .topMostViewController?
                .present(next: host)
        }

        shell.open(withTerminal: "xterm") { [weak self] in
            var size = self?.termianlSize ?? TerminalContext.defaultTerminalSize
            if size.width < 8 || size.height < 8 {
                // something went wrong
                size = TerminalContext.defaultTerminalSize
            }
            return size
        } withWriteData: { [weak self] in
            self?.getBuffer() ?? ""
        } withOutput: { [weak self] output in
            let sem = DispatchSemaphore(value: 0)
            mainActor {
                self?.termInterface.write(output)
                sem.signal()
            }
            sem.wait()
        } withContinuationHandler: { [weak self] in
            self?.continueDecision ?? false
        }

        termInterface.write("\r\n\r\n[*] Connection Closed ") // <- ending " " = make indicator greater again

        // leave loop
        debugPrint("\(self) \(#function) defer \(machine.id)")

        processShutdown()
    }

    func processShutdown() {
        mainActor {
            self.continueDecision = false
        }
        TerminalContext.queue.async {
            self.shell.requestDisconnectAndWait()
            self.shell = .init()
        }
    }
}

extension TerminalContext {
    struct DefaultPresent: View {
        let context: TerminalContext
        @Environment(\.presentationMode) var presentationMode

        var body: some View {
            NavigationView {
                TerminalView(context: context)
                    .toolbar {
                        ToolbarItem {
                            Button {
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                            }
                        }
                    }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
