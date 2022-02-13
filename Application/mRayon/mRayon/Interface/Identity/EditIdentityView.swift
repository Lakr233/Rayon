//
//  EditIdentityView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/2.
//

import RayonModule
import SwiftUI

struct EditIdentityView: View {
    @Environment(\.presentationMode) var presentationMode

    let inEditWith: (() -> (UUID?))?

    init(requestIdentity: (() -> (UUID?))? = nil) {
        inEditWith = requestIdentity
    }

    @State var initializedOnce = false

    @State var username: String = ""
    @State var password: String = ""
    @State var privateKey: String = ""
    @State var publicKey: String = ""
    @State var comment: String = ""
    @State var group: String = ""
    @State var autoAuth: Bool = true

    var body: some View {
        List {
            Section {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } header: {
                Label("Username", systemImage: "person")
            } footer: {
                Text("Username is identical to the parameter used during ssh login.")
            }

            Section {
                SecureField("Password", text: $password)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } header: {
                Label("Password", systemImage: "key")
            } footer: {
                Text("Password is used to either authenticate the session or decrypt the private key. It's optional.")
            }

            Section {
                privateKeyButtons
            } header: {
                Label("Private Key", systemImage: "lock.doc.fill")
            } footer: {
                Text(privateKeyDescription)
            }

            Section {
                publicKeyButtons
            } header: {
                Label("Public Key", systemImage: "lock.doc")
            } footer: {
                Text(publicKeyDescription)
            }

            Section {
                Toggle(isOn: $autoAuth) {
                    Label("Allow Auto Auth", systemImage: "a.circle.fill")
                }
            } header: {
                Label("Auto Auth", systemImage: "bolt.badge.a.fill")
            } footer: {
                Text("Use this key to authenticate server session automatically when needed.")
            }

            Section {
                TextField("Comment (Optional)", text: $comment)
            } header: {
                Label("Comment", systemImage: "bubble.left")
            } footer: {
                Text("Comment does not take any effect in authenticate, but keep you remember this identity.")
            }

//                Group is not available on iOS, :P
//                Section {
//                    TextField("Group", text: $group)
//                } header: {
//                    Label("Group", systemImage: "square.stack.3d.down.right")
//                } footer: {
//                    Text("")
//                }
            if let identity = inEditWith?() {
                Section {
                    Button {
                        UIBridge.requiresConfirmation(
                            message: "Are you sure you want to delete this identity?"
                        ) { confirmed in
                            if confirmed {
                                RayonStore.shared.identityGroup.delete(identity)
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    } label: {
                        Label("Delete Identity", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .onAppear {
            if initializedOnce { return }
            initializedOnce = true
            mainActor(delay: 0.1) { // <-- SwiftUI bug here, don't remove
                if let edit = inEditWith?() {
                    let read = RayonStore.shared.identityGroup[edit]
                    username = read.username
                    password = read.password
                    privateKey = read.privateKey
                    publicKey = read.publicKey
                    comment = read.comment
                    autoAuth = read.authenticAutomatically
                }
                if comment.isEmpty {
                    comment = "Created at: " + Date().formatted()
                }
            }
        }
        .navigationTitle("Edit Identity")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    completeSheet()
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
            }
        }
    }

    var privateKeyDescription: String {
        dataDescriptionFor(privateKey)
    }

    var publicKeyDescription: String {
        dataDescriptionFor(publicKey)
    }

    var privateKeyButtons: some View {
        Group {
            FilePicker(types: [.item], allowMultiple: false) { urls in
                guard let url = urls.first else {
                    return
                }
                loadPrivateKey(url: url)
            } label: {
                Label("Import from file", systemImage: "square.and.arrow.down.fill")
            }
            Button {
                loadPrivateKey(str: UIPasteboard.general.string)
            } label: {
                Label("Import from Pasteboard", systemImage: "doc.on.clipboard.fill")
            }
            Button {
                privateKey = ""
            } label: {
                Label("Clear Key Data", systemImage: "trash.fill")
            }
            .disabled(privateKey.isEmpty)
        }
    }

    var publicKeyButtons: some View {
        Group {
            FilePicker(types: [.item], allowMultiple: false) { urls in
                guard let url = urls.first else {
                    return
                }
                loadPublicKey(url: url)
            } label: {
                Label("Import from file", systemImage: "square.and.arrow.down.fill")
            }
            Button {
                loadPublicKey(str: UIPasteboard.general.string)
            } label: {
                Label("Import from Pasteboard", systemImage: "doc.on.clipboard.fill")
            }
            Button {
                publicKey = ""
            } label: {
                Label("Clear Key Data", systemImage: "trash.fill")
            }
            .disabled(publicKey.isEmpty)
        }
    }

    func loadPrivateKey(url: URL) {
        guard let data = try? String(contentsOfFile: url.path) else {
            UIBridge.presentError(with: "Unable to get key from file")
            return
        }
        loadPrivateKey(str: data)
    }

    func loadPublicKey(url: URL) {
        guard let data = try? String(contentsOfFile: url.path) else {
            UIBridge.presentError(with: "Unable to get key from file")
            return
        }
        loadPublicKey(str: data)
    }

    func loadPrivateKey(str: String?) {
        guard let str = str else {
            UIBridge.presentError(with: "Unable to get key from pasteboard")
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

    func loadPublicKey(str: String?) {
        guard let str = str else {
            UIBridge.presentError(with: "Unable to get key from pasteboard")
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

    func dataDescriptionFor(_ str: String) -> String {
        if str.count > 0,
           let data = str.data(using: .utf8),
           data.count > 0
        {
            return "<\(data.count)> bytes"
        }
        return "No Data (Optional)"
    }

    func completeSheet() {
        guard !username.isEmpty else {
            UIBridge.presentError(with: "Username can not be empty")
            return
        }

        var id = UUID()
        if let inEditWith = inEditWith,
           let readId = inEditWith()
        {
            id = readId
        }

        let newIdentity = RDIdentity(
            id: id,
            username: username,
            password: password,
            privateKey: privateKey,
            publicKey: publicKey,
            lastRecentUsed: Date(timeIntervalSince1970: 0),
            comment: comment,
            group: group,
            authenticAutomatically: autoAuth,
            attachment: [:]
        )

        RayonStore.shared.identityGroup[id] = newIdentity

        presentationMode.wrappedValue.dismiss()
    }
}

struct EditIdentityView_Previews: PreviewProvider {
    static var previews: some View {
        createPreview {
            AnyView(EditIdentityView())
        }
    }
}
