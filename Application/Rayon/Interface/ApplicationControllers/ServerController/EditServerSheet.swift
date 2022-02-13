//
//  EditServerSheet.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/10.
//

import SwiftUI

struct EditServerSheetView: View {
    let inEditWith: RDRemoteMachine.ID

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: RayonStore

    @State var remoteAddress = ""
    @State var remotePort = ""
    @State var name = ""
    @State var group = ""
    @State var comment = ""
    @State var associatedIdentity: UUID? = nil

    @State var openIdentityPicker: Bool = false

    var identityDescription: String {
        if let aid = associatedIdentity {
            return store.userIdentities[aid].shortDescription()
        }
        return "No Associated Identity"
    }

    var body: some View {
        SheetTemplate.makeSheet(
            title: "Edit Machine",
            body: AnyView(sheetBody)
        ) { confirmed in
            var shouldDismiss = false
            defer { if shouldDismiss { presentationMode.wrappedValue.dismiss() } }
            if !confirmed {
                shouldDismiss = true
                return
            }
            var generator = store.remoteMachines[inEditWith]
            generator.remoteAddress = remoteAddress
            generator.remotePort = remotePort
            generator.name = name
            generator.group = group
            generator.comment = comment
            generator.associatedIdentity = associatedIdentity?.uuidString
            store.remoteMachines.insert(generator)
            shouldDismiss = true
        }
        .onAppear {
            let read = store.remoteMachines[inEditWith]
            remoteAddress = read.remoteAddress
            remotePort = read.remotePort
            name = read.name
            group = read.group
            comment = read.comment
            if let aid = read.associatedIdentity,
               let auid = UUID(uuidString: aid)
            {
                associatedIdentity = auid
            }
        }
        .sheet(isPresented: $openIdentityPicker, onDismiss: nil, content: {
            IdentityPickerSheetView { rid in
                associatedIdentity = rid
            }
        })
        .frame(width: 600, height: 420)
    }

    var sheetBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                AlignedLabel("Name", icon: "mail.and.text.magnifyingglass")
                TextField("Name (Optional)", text: $name)
                AlignedLabel("Group", icon: "square.stack.3d.down.forward")
                TextField("Default (Optional)", text: $group)
                AlignedLabel("Comment", icon: "text.bubble")
                TextField("Comment (Optional)", text: $comment)
            }
            Group {
                AlignedLabel("Address", icon: "network")
                HStack {
                    TextField("Host Address", text: $remoteAddress)
                    Text(":")
                    TextField("Port", text: $remotePort)
                        .frame(width: 75)
                }
            }
            Group {
                AlignedLabel("Identity", icon: "person")
                HStack {
                    Text(identityDescription)
                        .font(.system(.body, design: .rounded))
                    Spacer()
                    Button {
                        openIdentityPicker = true
                    } label: {
                        Text("Browse...")
                    }
                }
            }
            sheetFoot
        }
    }

    var sheetFoot: some View {
        Group {
            Text("Editing with RayonID: \(inEditWith.uuidString)")
                .font(.system(.footnote, design: .monospaced))
        }
    }
}
