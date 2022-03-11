//
//  EditMachineView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/3.
//

import RayonModule
import SwiftUI

struct EditMachineView: View {
    @Environment(\.presentationMode) var presentationMode

    let inEditWith: (() -> (UUID?))?

    init(requestIdentity: (() -> (UUID?))? = nil) {
        inEditWith = requestIdentity
    }

    @State var initializedOnce = false

    @State var remoteAddress = ""
    @State var remotePort = ""
    @State var name = ""
    @State var group = ""
    @State var comment = ""
    @State var associatedIdentity: UUID? = nil

    var body: some View {
        List {
            Section {
                TextField("Name", text: $name)
                TextField("Comment (Optional)", text: $comment)
            } header: {
                Label("Name", systemImage: "mail.and.text.magnifyingglass")
            }

            Section {
                TextField("Host Address", text: $remoteAddress)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    .onChange(of: remoteAddress) { newValue in
                        let get = newValue.replacingOccurrences(of: "。", with: ".")
                        if remoteAddress != get { remoteAddress = get }
                    }
                TextField("Host Port", text: $remotePort)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.numberPad)
            } header: {
                Label("Address", systemImage: "link")
            }

            Section {
                Button {
                    DispatchQueue.global().async {
                        let identity = RayonUtil.selectIdentity()
                        mainActor {
                            self.associatedIdentity = identity
                        }
                    }
                } label: {
                    Label("Select Identity", systemImage: "arrow.right")
                        .foregroundColor(.accentColor)
                }
            } header: {
                Label("Identity", systemImage: "person")
            } footer: {
                if let aid = associatedIdentity {
                    Text(RayonStore.shared.identityGroup[aid].shortDescription())
                } else {
                    Text("No Associated Identity (Optional)")
                }
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
                            message: "Are you sure you want to delete this machine?"
                        ) { confirmed in
                            if confirmed {
                                RayonStore.shared.machineGroup.delete(identity)
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    } label: {
                        Label("Delete Machine", systemImage: "trash")
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
                    let read = RayonStore.shared.machineGroup[edit]
                    remoteAddress = read.remoteAddress
                    remotePort = read.remotePort
                    name = read.name
                    group = read.group
                    comment = read.comment
                    if let aid = read.associatedIdentity {
                        associatedIdentity = UUID(uuidString: aid)
                    }
                }
                if comment.isEmpty {
                    comment = "Created at: " + Date().formatted()
                }
                if remotePort.isEmpty {
                    remotePort = "22"
                }
            }
        }
        .navigationTitle("Edit Machine")
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

    func completeSheet() {
        guard !name.isEmpty else {
            UIBridge.presentError(with: "Empty Name")
            return
        }
        guard !remoteAddress.isEmpty else {
            UIBridge.presentError(with: "Empty Address")
            return
        }
        guard !remotePort.isEmpty else {
            UIBridge.presentError(with: "Empty Port")
            return
        }

        var id = UUID()
        if let inEditWith = inEditWith,
           let readId = inEditWith()
        {
            id = readId
        }

        let newMachine = RDMachine(
            id: id,
            remoteAddress: remoteAddress,
            remotePort: remotePort,
            name: name,
            group: group,
            comment: comment,
            associatedIdentity: associatedIdentity?.uuidString
        )
        RayonStore.shared.machineGroup.insert(newMachine)

        presentationMode.wrappedValue.dismiss()
    }
}

struct EditMachineView_Previews: PreviewProvider {
    static var previews: some View {
        createPreview { AnyView(EditMachineView()) }
    }
}
