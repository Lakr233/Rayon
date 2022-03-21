//
//  MachineActionView.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2018/3/1.
//

import RayonModule
import SwiftUI

struct MachineActionView: View {
    let machine: RDMachine.ID

    @EnvironmentObject var store: RayonStore

    @State var openEdit: Bool = false

    var body: some View {
        Group {
            Button {
                deleteButtonTapped()
            } label: {
                Image(systemName: "trash")
                    .frame(width: 15)
            }
            .foregroundColor(.accentColor)
            Button {
                duplicateButtonTapped()
            } label: {
                Image(systemName: "plus.square.on.square")
                    .frame(width: 15)
            }
            .foregroundColor(.accentColor)
            Button {
                openEdit = true
            } label: {
                Image(systemName: "pencil")
                    .frame(width: 15)
            }
            .foregroundColor(.accentColor)
            Button {
                MenubarTool.shared.createRuncat(for: machine)
            } label: {
                Image(nsImage: NSImage(named: "cat_frame_0")!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(-2)
                    .frame(width: 15)
            }
            .foregroundColor(.accentColor)
            Button {
                FileTransferManager.shared.begin(for: machine)
            } label: {
                Image(systemName: "externaldrive.connected.to.line.below.fill")
                    .frame(width: 15)
            }
            .foregroundColor(.accentColor)
            Button {
                beingConnect()
            } label: {
                Image(systemName: "cable.connector.horizontal")
                    .frame(width: 15)
            }
            .foregroundColor(.accentColor)
        }
        .sheet(isPresented: $openEdit, onDismiss: nil) {
            MachineEditView(inEditWith: machine)
        }
    }

    func beingConnect() {
        TerminalManager.shared.createSession(withMachineID: machine)
    }

    func duplicateButtonTapped() {
        UIBridge.requiresConfirmation(
            message: "You are about to duplicate this item"
        ) { confirmed in
            guard confirmed else { return }
            let index = store
                .machineGroup
                .machines
                .firstIndex { $0.id == machine }
            if let index = index {
                var machine = store.machineGroup.machines[index]
                machine.id = UUID()
                store.machineGroup.insert(machine)
            }
        }
    }

    func deleteButtonTapped() {
        UIBridge.requiresConfirmation(
            message: "You are about to delete this item"
        ) { confirmed in
            guard confirmed else { return }
            store.machineGroup.delete(machine)
            store.cleanRecentIfNeeded()
        }
    }
}
