//
//  CreateServerView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import NSRemoteShell
import SwiftUI

struct CreateServerView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: RayonStore

    let requiresDismissAction: Bool

    @State var serverLocation: String = ""
    @State var serverPort: String = "22"
    @State var identitySelection: RDIdentity.ID? = nil
    @State var constructorSession: NSRemoteShell? = nil

    @State var showProgressView: Bool = false
    @State var showIdentityPickerView: Bool = false
    @State var createWithoutConnectView: Bool = false

    var body: some View {
        remoteAddressView
            .requiresSheetFrame()
            .toolbar {
                ToolbarItem {
                    Button {
                        UIBridge.requiresConfirmation(
                            message: "The document that is attempting to open is from third part community, we are not reasonable for anything related to this document."
                        ) { confirmed in
                            if confirmed {
                                UIBridge.open(url: URL(string: "https://docs.digitalocean.com/support/ssh-troubleshooting")!)
                            }
                        }
                    } label: {
                        Label("SSH Troubleshoot", systemImage: "questionmark")
                    }
                }
            }
            .animation(.interactiveSpring(), value: serverLocation)
            .animation(.interactiveSpring(), value: serverPort)
            .background(
                Button {
                    if requiresDismissAction {
                        presentationMode.wrappedValue.dismiss()
                    }
                } label: {
                    Text("Dismiss")
                }
                .keyboardShortcut(.cancelAction)
                // keyboard shortcut won't on button style nor hidden
                .offset(y: -10000)
            )
            .expended()
            .navigationTitle("Create Server")
            .sheet(isPresented: $showProgressView, onDismiss: nil) {
                SheetTemplate.makeProgress(text: "Operation in progress")
            }
            .sheet(isPresented: $createWithoutConnectView, onDismiss: nil) {
                EditServerSheetView(inEditWith: UUID())
            }
            .sheet(isPresented: $showIdentityPickerView) {
                continueProcessIfAvailable()
            } content: {
                IdentityPickerSheetView { identity in
                    identitySelection = identity
                }
            }
    }

    var remoteAddressView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Create Server", systemImage: "plus.viewfinder")
                .font(.system(.title, design: .rounded))
            Text("Rayon is a lobby boy that helps you to manage your servers.")
            Divider()
            Text("Accepted Connection: Secure Shell")
            Text("By entering your server address, we will guide you through the server creation process.")

            HStack {
                TextField("www.example.com", text: $serverLocation)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(6)
                    .background(
                        Rectangle()
                            .opacity(0.1)
                            .roundedCorner()
                    )
                Text(":")
                TextField("Port", text: $serverPort)
                    .onSubmit {
                        if serverLocation.count == 0 {
                            return
                        }
                        if UInt16(serverPort) == nil {
                            return
                        }
                        beginConnectButton()
                    }
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(6)
                    .background(
                        Rectangle()
                            .opacity(0.1)
                            .roundedCorner()
                    )
                    .frame(width: 75)
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))

            Button {
                createWithoutConnectView = true
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.trianglebadge.exclamationmark")
                    Text("Create Without Connection")
                        .underline()
                }
                .font(.system(.footnote, design: .rounded))
            }
            .foregroundColor(.accentColor)
            .buttonStyle(.borderless)

            Divider()
            HStack {
                Button {
                    beginConnectButton()
                } label: {
                    Text("Begin Connection")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(
                            Rectangle()
                                .foregroundColor(.orange)
                                .roundedCorner()
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(serverLocation.count == 0)
                .disabled(UInt16(serverPort) == nil)

                if requiresDismissAction {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("Cancel")
                            .foregroundColor(.accentColor)
                            .padding(10)
                            .background(
                                Rectangle()
                                    .foregroundColor(Color.accentColor.opacity(0.1))
                                    .roundedCorner()
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
            }
        }
        .padding()
    }

    func mainActorProgressView(show: Bool) {
        mainActor {
            showProgressView = show
        }
    }

    func mainActorIdentityPicker(show: Bool) {
        mainActor { showIdentityPickerView = show }
    }

    func beginConnectButton() {
        DispatchQueue.global().async {
            mainActorProgressView(show: true)

            func createRemote() -> NSRemoteShell {
                NSRemoteShell()
                    .setupConnectionHost(serverLocation)
                    .setupConnectionPort(NSNumber(value: Int(serverPort) ?? 0))
                    .setupConnectionTimeout(6)
                    .requestConnectAndWait()
            }

            var remote = createRemote()
            guard remote.isConnected else {
                mainActorProgressView(show: false)
                UIBridge.presentError(with: "Unable to connect to \(serverLocation) with port \(serverPort)")
                return
            }

            var lastLoginUsername: String?
            for identity in store.userIdentitiesForAutoAuth {
                if let lastUsername = lastLoginUsername, lastUsername != identity.username {
                    remote = createRemote()
                    if !remote.isConnected { break } // just break
                }
                lastLoginUsername = identity.username
                identity.callAuthenticationWith(remote: remote)
                if remote.isAuthenicated {
                    mainActorProgressView(show: false)
                    store.registerServer(
                        withAddress: serverLocation,
                        withPort: serverPort,
                        withIdentity: identity.id,
                        session: remote
                    )
                    afterSuccess()
                    return
                }
            }

            mainActorProgressView(show: false)
            mainActor(delay: 0.5) {
                mainActorIdentityPicker(show: true)
            }
        }
    }

    func continueProcessIfAvailable() {
        guard let identitySelection = identitySelection else {
            return
        }
        debugPrint("continue authentication process by using identity \(identitySelection)")
        let identity = store.userIdentities[identitySelection]
        mainActorProgressView(show: true)
        DispatchQueue.global().async {
            // we don't hold session, so we can re-auth with different username
            let remote = NSRemoteShell()
                .setupConnectionHost(serverLocation)
                .setupConnectionPort(NSNumber(value: Int(serverPort) ?? 0))
                .setupConnectionTimeout(6)
                .requestConnectAndWait()
            identity.callAuthenticationWith(remote: remote)
            debugPrint(remote.isAuthenicated)
            guard remote.isAuthenicated else {
                mainActorProgressView(show: false)
                UIBridge.presentError(with: "Unable to authenticate session")
                return
            }
            mainActorProgressView(show: false)
            mainActor(delay: 0.5) {
                store.registerServer(
                    withAddress: serverLocation,
                    withPort: serverPort,
                    withIdentity: identitySelection,
                    session: remote
                )
                afterSuccess()
            }
        }
    }

    func afterSuccess() {
        if requiresDismissAction {
            presentationMode.wrappedValue.dismiss()
        }
        mainActor(delay: 0.5) {
            UIBridge.presentAlert(with: "Successfully created a server")
        }
    }
}
