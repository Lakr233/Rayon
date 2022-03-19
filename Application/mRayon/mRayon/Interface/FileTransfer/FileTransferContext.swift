//
//  FileTransferContext.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/18.
//

import NSRemoteShell
import RayonModule
import SwiftUI
import UIKit

class FileTransferContext: ObservableObject, Identifiable, Equatable {
    var id: UUID = .init()

    var navigationTitle: String {
        machine.name
    }

    @Published var navigationSubtitle: String = ""

    let machine: RDMachine
    let identity: RDIdentity?
    var shell: NSRemoteShell = .init()
    var firstConnect: Bool = true

    var destroyedSession: Bool = false {
        didSet {
            shell.destroyPermanently()
        }
    }

    @Published var lastError: String = ""
    @Published var interfaceToken: UUID = .init()
    @Published var currentDir: String = "/" {
        didSet {
            navigationSubtitle = currentDir
        }
    }

    @Published var currentFileList: [RemoteFile] = []

    struct RemoteFile: Identifiable, Equatable, Hashable {
        var id: RemoteFile { self }
        let base: URL
        let name: String
        let fstat: NSRemoteFile
    }

    // MARK: SHELL CONTEXT -

    init(machine: RDMachine, identity: RDIdentity? = nil) {
        self.machine = machine
        self.identity = identity
        DispatchQueue.global().async {
            self.processBootstrap()
        }
    }

    static func == (lhs: FileTransferContext, rhs: FileTransferContext) -> Bool {
        lhs.id == rhs.id
    }

    func setupShellData() {
        shell
            .setupConnectionHost(machine.remoteAddress)
            .setupConnectionPort(NSNumber(value: Int(machine.remotePort) ?? 0))
            .setupConnectionTimeout(RayonStore.shared.timeoutNumber)
    }

    func putInformation(_ str: String) {
        mainActor {
            self.lastError = str
        }
    }

    func processBootstrap() {
        mainActor {
            guard self.firstConnect else { return }
            self.firstConnect = false
            guard RayonStore.shared.openInterfaceAutomatically else { return }
            let host = UIHostingController(
                rootView: DefaultPresent(context: self)
            )
            host.isModalInPresentation = true
            host.modalTransitionStyle = .coverVertical
            host.modalPresentationStyle = .formSheet
            host.preferredContentSize = preferredPopOverSize
            UIWindow.shutUpKeyWindow?
                .topMostViewController?
                .present(next: host)
        }
        callConnect()
    }

    func callConnect() {
        setupShellData()

        debugPrint("\(self) \(#function) \(machine.id)")
        shell.requestConnectAndWait()
        guard shell.isConnected else {
            putInformation("Unable to connect for \(machine.remoteAddress):\(machine.remotePort)")
            return
        }

        if let idd = identity {
            idd.callAuthenticationWith(remote: shell)
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
        }

        guard shell.isConnected, shell.isAuthenicated else {
            putInformation("Failed to authenticate connection, did you forget to add identity or enable auto authentication?")
            return
        }

        debugPrint("sftp session for \(machine.name) is now connected")
    }

    func processShutdown(exitFromShell _: Bool = false) {
        lastError = ""
        // you are in charge to cancel sftp operation at interface level
        // because sftp operations are in control blocks which are not canceled during fly
        // I may add a control later tho
        DispatchQueue.global().async { [weak shell] in
            shell?.requestDisconnectAndWait()
        }
    }
}

extension FileTransferContext {
    struct DefaultPresent: View {
        let context: FileTransferContext
        @Environment(\.presentationMode) var presentationMode

        var body: some View {
            NavigationView {
                FileTransferView(context: context)
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
