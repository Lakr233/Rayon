//
//  TerminalManager+Context.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/3/10.
//

import Foundation
import NSRemoteShell
import RayonModule
import SwiftUI
import XTerminalUI

extension TerminalManager {
    class Context: ObservableObject, Identifiable, Equatable {
        var id: UUID = .init()

        var navigationTitle: String {
            switch remoteType {
            case .machine: return machine.shortDescription()
            case .command: return command?.command ?? "Unknown Command"
            }
        }

        @Published var navigationSubtitle: String = ""

        private var title: String = "" {
            didSet {
                mainActor {
                    self.navigationSubtitle = self.title
                }
            }
        }

        enum RemoteType {
            case machine
            case command
        }

        let remoteType: RemoteType

        let machine: RDMachine
        let command: SSHCommandReader?
        var shell: NSRemoteShell = .init()

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
            Context.queue.async { [weak self] in
                self?.shell.explicitRequestStatusPickup()
            }
        }

        var continueDecision: Bool = true {
            didSet {
                mainActor {
                    self.interfaceDisabled = !self.continueDecision
                }
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
            Context.queue.async {
                self.processBootstrap()
                self.processShutdown()
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
            Context.queue.async {
                self.processBootstrap()
                self.processShutdown()
            }
        }

        func setupShellData() {
            shell
                .setupConnectionHost(machine.remoteAddress)
                .setupConnectionPort(NSNumber(value: Int(machine.remotePort) ?? 0))
                .setupConnectionTimeout(6)
        }

        static func == (lhs: Context, rhs: Context) -> Bool {
            lhs.id == rhs.id
        }

        func putInformation(_ str: String) {
            termInterface.write(str + "\r\n")
        }

        func processBootstrap() {
            setupShellData()

            debugPrint("\(self) \(#function) \(machine.id)")
            putInformation("[*] Creating Connection")
            continueDecision = true

            termInterface
                .setupBellChain {
                    debugPrint("terminal bell")
                }
                .setupBufferChain { [weak self] buffer in
                    self?.insertBuffer(buffer)
                }
                .setupTitleChain { [weak self] str in
                    self?.title = str
                }

            shell.requestConnectAndWait()

            guard shell.isConnected else {
                putInformation("Unable to connect for \(machine.remoteAddress):\(machine.remotePort)")
                return
            }

            if let rid = machine.associatedIdentity {
                guard let uid = UUID(uuidString: rid) else {
                    putInformation("Malformed machine data")
                    return
                }
                let identity = RayonStore.shared.identityGroup[uid]
                guard !identity.username.isEmpty else {
                    putInformation("Malformed identity data")
                    return
                }
                identity.callAuthenticationWith(remote: shell)
            } else {
                var previousUsername: String?
                for identity in RayonStore.shared.identityGroupForAutoAuth {
                    putInformation("[i] trying to authenticate with \(identity.shortDescription())")
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
                putInformation("")
                // user may get confused if multiple session opened the picker
//                if !shell.isAuthenicated,
//                   let identity = RayonUtil.selectIdentity()
//                {
//                    RayonStore.shared
//                        .identityGroup[identity]
//                        .callAuthenticationWith(remote: shell)
//                }
            }

            guard shell.isConnected, shell.isAuthenicated else {
                putInformation("Failed to authenticate connection")
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

            shell.open(withTerminal: "xterm") { [weak self] in
                var size = self?.termianlSize ?? Context.defaultTerminalSize
                if size.width < 8 || size.height < 8 {
                    // something went wrong
                    size = Context.defaultTerminalSize
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

            putInformation("")
            putInformation("[*] Connection Closed")

            // leave loop
            debugPrint("\(self) \(#function) defer \(machine.id)")

            processShutdown()
        }

        func processShutdown() {
            continueDecision = false
            Context.queue.async {
                self.shell.requestDisconnectAndWait()
            }
        }
    }
}
