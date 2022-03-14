//
//  SnippetExecuteContext.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/4.
//

import NSRemoteShell
import RayonModule
import SwiftUI
import XTerminalUI

class SnippetExecuteContext: ObservableObject {
    let snippet: RDSnippet
    let machineGroup: [RDMachine]
    var shellGroup: [NSRemoteShell]
    let terminalGroup: [STerminalView]

    @Published var interfaceAllocated = false

    @Published var running: [RDMachine] = []
    @Published var completed: [RDMachine] = []
    @Published var hasError: Bool = false
    @Published var completedProgress: Float = 0
    @Published var totalProgress: Float = 2_147_483_648 // will update

    static let queue = DispatchQueue(label: "wiki.qaq.snippet.exec", attributes: .concurrent)

    init(snippet: RDSnippet, machineGroup: [RDMachine]) {
        self.snippet = snippet
        self.machineGroup = machineGroup
        var buildTermUI = [STerminalView]()
        machineGroup.forEach { _ in
            buildTermUI.append(.init())
        }
        terminalGroup = buildTermUI
        shellGroup = machineGroup
            .map {
                NSRemoteShell()
                    .setupConnectionHost($0.remoteAddress)
                    .setupConnectionPort(NSNumber(value: Int($0.remotePort) ?? 0))
                    .setupConnectionTimeout(6)
            }
    }

    deinit {
        debugPrint("\(self) \(#function)")
    }

    func beginBootstrap() {
        interfaceAllocated = true
        running = machineGroup
        updateProgress()
        for idx in 0 ..< machineGroup.count {
            let machine = machineGroup[idx]
            let shell = shellGroup[idx]
            let term = terminalGroup[idx]
            SnippetExecuteContext.queue.async {
                self.createExecute(for: machine, shell: shell, term: term)
            }
        }
    }

    func updateProgress() {
        mainActor { [self] in
            debugPrint("\(self) \(completed.count)")
            completedProgress = Float(completed.count)
            totalProgress = Float(machineGroup.count)
        }
    }

    func reportError() {
        mainActor { self.hasError = true }
    }

    func createExecute(for machine: RDMachine, shell: NSRemoteShell, term: STerminalView) {
        defer {
            moveToComplete(for: machine.id)
        }
        term.write("[*] connecting to host...\r\n")
        shell.requestConnectAndWait()
        guard shell.isConnected else {
            term.write("[E] failed to connect\r\n")
            reportError()
            return
        }
        if let aid = machine.associatedIdentity {
            guard let uid = UUID(uuidString: aid) else {
                term.write("[E] failed to authenticate\r\n")
                reportError()
                return
            }
            let identity = RayonStore.shared.identityGroup[uid]
            guard !identity.username.isEmpty else {
                term.write("[E] failed to authenticate\r\n")
                reportError()
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
        }
        guard shell.isConnected, shell.isAuthenicated else {
            term.write("[E] failed to authenticate session\r\n")
            reportError()
            return
        }
        shell.beginExecute(
            withCommand: snippet.code,
            withTimeout: 0
        ) {
            term.write("[*] Execute Begin")
        } withOutput: { output in
            // because the output is picked up by xterm, we need to replace \n to \r\n
            let output = output
                .replacingOccurrences(of: "\n", with: "\r\n") // \n -> \r\n, \r\n -> \r\r\n
                .replacingOccurrences(of: "\r\r\n", with: "\r\n") // \r\r -> \n
            term.write(output)
        } withContinuationHandler: {
            true // close it to cancel the exec
        }
        term.write("\r\n\r\n[*] Execution Completed ")
    }

    func moveToComplete(for mid: RDMachine.ID) {
        mainActor { [self] in
            defer { updateProgress() }
            let index = running.firstIndex { $0.id == mid }
            if let index = index {
                let get = running.remove(at: index)
                completed.append(get)
                shellGroup[index] = .init()
            }
        }
    }

    func close(for mid: RDMachine.ID) {
        mainActor { [self] in
            defer { updateProgress() }
            let index = machineGroup.firstIndex { $0.id == mid }
            if let index = index {
                let shell = shellGroup[index]
                SnippetExecuteContext.queue.async {
                    shell.requestDisconnectAndWait()
                }
            }
        }
    }
}
