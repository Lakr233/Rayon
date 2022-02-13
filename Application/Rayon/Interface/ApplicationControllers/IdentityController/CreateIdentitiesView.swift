//
//  CreateIdentitiesView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import SwiftUI

struct CreateIdentitiesView: View {
    @Binding var selection: RDIdentity.ID?

    @State var username: String = ""
    @State var password: String = ""
    @State var privateKey: String = ""
    @State var publicKey: String = ""
    @State var comment: String = ""
    @State var group: String = ""

    var onComplete: ((RDIdentity.ID?) -> Void)?

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        SheetTemplate.makeSheet(
            title: "Create Identity",
            body: AnyView(sheetBody)
        ) { confirmed in
            var shouldDismiss = false
            defer { if shouldDismiss { presentationMode.wrappedValue.dismiss() } }
            if !confirmed {
                shouldDismiss = true
                return
            }
            guard username.count > 0 else {
                UIBridge.presentError(with: "Username is required")
                return
            }
            if let edit = selection {
                var rid = RayonStore.shared.userIdentities[edit]
                rid.username = username
                rid.password = password
                rid.privateKey = privateKey
                rid.publicKey = publicKey
                rid.comment = comment
                RayonStore.shared.userIdentities.insert(rid)
                mainActor {
                    onComplete?(rid.id)
                }
            } else {
                let object = RDIdentity(
                    username: username,
                    password: password,
                    privateKey: privateKey,
                    publicKey: publicKey,
                    lastRecentUsed: .init(timeIntervalSince1970: 0),
                    comment: comment,
                    group: group,
                    authenticAutomatically: true,
                    attachment: [:]
                )
                RayonStore.shared.userIdentities.insert(object)
                mainActor {
                    onComplete?(object.id)
                }
            }
            shouldDismiss = true
        }
        .onAppear {
            if let edit = selection {
                let rid = RayonStore.shared.userIdentities[edit]
                username = rid.username
                password = rid.password
                privateKey = rid.privateKey
                publicKey = rid.publicKey
                comment = rid.comment
            } else {
                comment = "Created at: " + Date().formatted()
            }
        }
    }

    var sheetBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            AlignedLabel("Username", icon: "person.fill")
            TextField("Username", text: $username)
                .disableAutocorrection(true)

            AlignedLabel("Password", icon: "lock.fill")
            SecureField("Password (Optional)", text: $password)
                .disableAutocorrection(true)

            AlignedLabel("Key Pair", icon: "key.fill")
            publicKeyView
            privateKeyView

            AlignedLabel("Comment", icon: "text.bubble")
            TextField("Comment (Optional)", text: $comment)
                .disableAutocorrection(true)
        }
        .frame(width: 400)
    }

    var publicKeyView: some View {
        HStack {
            Text("> Public Key: \(dataDescriptionFor(publicKey))")
                .font(.system(.body, design: .monospaced))
            Spacer()
            Button {
                guard publicKey.count == 0 else {
                    publicKey = ""
                    return
                }
                openFilePicker { data in
                    guard let data = data,
                          let str = String(data: data, encoding: .utf8)
                    else {
                        UIBridge.presentError(with: "Failed to open file")
                        return
                    }
                    if str.contains("ssh-rsa") {
                        publicKey = str
                    } else {
                        UIBridge.requiresConfirmation(
                            message: "File dose not look like a public key, still load the key?"
                        ) { confirmed in
                            if confirmed { publicKey = str }
                        }
                    }
                }
            } label: {
                if publicKey.count > 0 {
                    Text("Delete")
                } else {
                    Text("Browse...")
                }
            }
        }
    }

    var privateKeyView: some View {
        HStack {
            Text("> Private Key: \(dataDescriptionFor(privateKey))")
                .font(.system(.body, design: .monospaced))
            Spacer()
            Button {
                guard privateKey.count == 0 else {
                    privateKey = ""
                    return
                }
                openFilePicker { data in
                    guard let data = data,
                          let str = String(data: data, encoding: .utf8)
                    else {
                        UIBridge.presentError(with: "Failed to open file")
                        return
                    }
                    if str.contains("PRIVATE KEY") {
                        privateKey = str
                    } else {
                        UIBridge.requiresConfirmation(
                            message: "File dose not look like a private key, still load the key?"
                        ) { confirmed in
                            if confirmed { privateKey = str }
                        }
                    }
                }
            } label: {
                if privateKey.count > 0 {
                    Text("Delete")
                } else {
                    Text("Browse...")
                }
            }
        }
    }

    func dataDescriptionFor(_ str: String) -> String {
        if str.count > 0,
           let data = str.data(using: .utf8),
           data.count > 0
        {
            return "<\(data.count)> bytes"
        }
        return "No Data (Optional)"
    }

    func openFilePicker(onComplete: @escaping (Data?) -> Void) {
        #if os(macOS)
            let panel = NSOpenPanel()
            panel.directoryURL = URL(fileURLWithPath: "\(NSHomeDirectory())/.ssh/")
            panel.canChooseFiles = true
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            func handle(respnse: NSApplication.ModalResponse) {
                if respnse == .OK, let url = panel.url {
                    // panel animation
                    mainActor(delay: 0.5) {
                        onComplete(try? Data(contentsOf: url))
                    }
                }
            }
            if let window = NSApplication.shared.keyWindow {
                panel.beginSheetModal(for: window) { handle(respnse: $0) }
            } else {
                panel.begin { handle(respnse: $0) }
            }
        #else
            return nil
        #endif
    }
}
