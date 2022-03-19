//
//  MonitorContext.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/3.
//

import Foundation
import MachineStatus
import NSRemoteShell
import RayonModule
import SwiftUI

class MonitorContext: ObservableObject, Identifiable, Equatable {
    var id: UUID = .init()
    var title: String = ""

    let machine: RDMachine
    let identity: RDIdentity

    var status: ServerStatus = .init()

    private(set) var isLoading: Bool = false

    private var shell: NSRemoteShell

    @Published var closed: Bool = false

    private var loopContinue: Bool = true

    private static let queue = DispatchQueue(
        label: "wiki.qaq.monitor",
        attributes: .concurrent
    )

    init(machine: RDMachine, identity: RDIdentity) {
        self.machine = machine
        self.identity = identity

        title = machine.name

        shell = .init()
            .setupConnectionHost(machine.remoteAddress)
            .setupConnectionPort(NSNumber(value: Int(machine.remotePort) ?? 0))
            .setupConnectionTimeout(6)

        MonitorContext.queue.async {
            self.processBootstrap()
        }
    }

    deinit {
        debugPrint("\(self) \(#function) \(machine.id) \(identity.id)")
    }

    static func == (lhs: MonitorContext, rhs: MonitorContext) -> Bool {
        lhs.id == rhs.id
    }

    func processBootstrap() {
        debugPrint("\(self) \(#function) \(machine.id) \(identity.id)")
        // enter loop
        updateLoop()
        // leave loop
        debugPrint("\(self) \(#function) defer \(machine.id) \(identity.id)")
    }

    func updateLoop() {
        while loopContinue {
            mainActor { self.isLoading = true }
            // connect + auth
            if !(shell.isConnected && shell.isAuthenicated) {
                connectAndAuthenticate()
            }
            // pull down data
            if shell.isConnected, shell.isAuthenicated {
                mainActor {
                    var read = RayonStore.shared.machineGroup[self.machine.id]
                    if read.isNotPlaceholder() {
                        read.lastBanner = self.shell.remoteBanner ?? "No Banner"
                        RayonStore.shared.machineGroup[self.machine.id] = read
                    }
                }
                status.requestInfoAndWait(with: shell)
            }
            mainActor { self.isLoading = false }
            // don't hurt cpu lol
            sleep(5)
        }
        closed = true
    }

    func connectAndAuthenticate() {
        shell.requestConnectAndWait()
        identity.callAuthenticationWith(remote: shell)
    }

    func processShutdown() {
        mainActor {
            self.loopContinue = false
            self.closed = true
        }
        MonitorContext.queue.async {
            self.shell.requestDisconnectAndWait()
            self.shell.destroyPermanently()
        }
    }
}

extension MonitorContext {
    struct DefaultPresent: View {
        let context: MonitorContext
        @Environment(\.presentationMode) var presentationMode

        var body: some View {
            NavigationView {
                MonitorView(context: context)
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
        }
    }
}
