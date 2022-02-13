//
//  RemoteMachineView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/10.
//

import SwiftUI

struct RemoteMachineView: View {
    let machine: RDRemoteMachine.ID

    @EnvironmentObject var store: RayonStore

    @State var openEditSheet: Bool = false

    let redactedColor: Color = .green

    var body: some View {
        contentView
            .contextMenu {
                Button {
                    let index = store
                        .remoteMachines
                        .machines
                        .firstIndex { $0.id == machine }
                    if let index = index {
                        store.remoteMachines.machines.remove(at: index)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .background(
                Color.accentColor
                    .opacity(0.05)
                    .roundedCorner()
            )
            .sheet(isPresented: $openEditSheet, onDismiss: nil, content: {
                EditServerSheetView(inEditWith: machine)
            })
    }

    var contentView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "server.rack")
                HStack {
                    TextField("Server Name", text: $store.remoteMachines[machine].name)
                        .textFieldStyle(PlainTextFieldStyle())
                    Spacer()
                }
                .overlay(
                    Rectangle()
                        .cornerRadius(2)
                        .foregroundColor(redactedColor)
                        .expended()
                        .opacity(
                            store.remoteMachineRedactedLevel.rawValue > 1 ? 1 : 0
                        )
                )
            }
            .font(.system(.headline, design: .rounded))
            HStack {
                TextField("Server Address", text: $store.remoteMachines[machine].remoteAddress)
                    .textFieldStyle(PlainTextFieldStyle())
                Spacer()
                TextField("Port", text: $store.remoteMachines[machine].remotePort)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 50)
            }
            .overlay(
                Rectangle()
                    .cornerRadius(2)
                    .foregroundColor(redactedColor)
                    .expended()
                    .opacity(
                        store.remoteMachineRedactedLevel.rawValue > 0 ? 1 : 0
                    )
            )
            .font(.system(.subheadline, design: .rounded))
            Divider()
            HStack(spacing: 4) {
                VStack(alignment: .trailing, spacing: 5) {
                    Text("Activity:")
                        .lineLimit(1)
                    Text("Banner:")
                        .lineLimit(1)
                    Text("Comment:")
                        .lineLimit(1)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(
                        store.remoteMachines[machine]
                            .lastConnection
                            .formatted(date: .abbreviated, time: .omitted)
                    )
                    .lineLimit(1)
                    Text(
                        store.remoteMachines[machine]
                            .lastBanner
                            .count > 0 ?
                            store.remoteMachines[machine].lastBanner
                            : "Not Identified"
                    )
                    .lineLimit(1)
                    TextField("No Comment", text: $store.remoteMachines[machine].comment)
                        .textFieldStyle(PlainTextFieldStyle())
                        .lineLimit(1)
                }
            }
            .font(.system(.caption, design: .rounded))
            .overlay(
                Rectangle()
                    .cornerRadius(2)
                    .foregroundColor(redactedColor)
                    .expended()
                    .opacity(
                        store.remoteMachineRedactedLevel.rawValue > 1 ? 1 : 0
                    )
            )
            .textSelection(.enabled)
            Divider()
            Text(machine.uuidString)
                .textSelection(.enabled)
                .font(.system(size: 5, weight: .light, design: .monospaced))
        }
        .animation(.interactiveSpring(), value: store.remoteMachineRedactedLevel)
        .frame(maxWidth: .infinity)
        .padding()
    }
}

struct RemoteMachineFloatingPanelView: View {
    let machine: RDRemoteMachine.ID

    @EnvironmentObject var store: RayonStore

    @State var openEdit: Bool = false

    var body: some View {
        Group {
            Button {
                deleteButtonTapped()
            } label: {
                Image(systemName: "trash")
            }
            .foregroundColor(.accentColor)
            Button {
                duplicateButtonTapped()
            } label: {
                Image(systemName: "plus.square.on.square")
            }
            .foregroundColor(.accentColor)
            Button {
                openEdit = true
            } label: {
                Image(systemName: "pencil")
            }
            .foregroundColor(.accentColor)
            Button {
                beingConnect()
            } label: {
                Image(systemName: "cable.connector.horizontal")
            }
            .foregroundColor(.accentColor)
        }
        .sheet(isPresented: $openEdit, onDismiss: nil) {
            EditServerSheetView(inEditWith: machine)
        }
    }

    func beingConnect() {
        var lookup = false
        for session in store.remoteSessions where session.context.remoteMachine.id == machine {
            lookup = true
            break
        }
        if lookup {
            UIBridge.requiresConfirmation(message: "A session is already in place, are you sure to open another?") { confirmed in
                if confirmed {
                    store.beginSessionStartup(for: machine)
                }
            }
        } else {
            store.beginSessionStartup(for: machine)
        }
    }

    func duplicateButtonTapped() {
        UIBridge.requiresConfirmation(
            message: "You are about to duplicate this item"
        ) { confirmed in
            guard confirmed else { return }
            let index = store
                .remoteMachines
                .machines
                .firstIndex { $0.id == machine }
            if let index = index {
                var machine = store.remoteMachines.machines[index]
                machine.id = UUID()
                store.remoteMachines.machines.append(machine)
            }
        }
    }

    func deleteButtonTapped() {
        UIBridge.requiresConfirmation(
            message: "You are about to delete this item"
        ) { confirmed in
            guard confirmed else { return }
            let index = store
                .remoteMachines
                .machines
                .firstIndex { $0.id == machine }
            if let index = index {
                store.remoteMachines.machines.remove(at: index)
            }
            store.cleanRecentIfNeeded()
        }
    }
}
