//
//  MachineElement.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/2.
//

import RayonModule
import SwiftUI
import SwiftUIPolyfill

struct MachineElementView: View {
    let machine: RDMachine.ID

    @EnvironmentObject var store: RayonStore
    let redactedColor: Color = .green

    @State var openEdit = false

    var body: some View {
        contentView
            .overlay {
                Menu {
                    Section {
                        Button {
                            MonitorManager.shared.begin(for: machine)
                        } label: {
                            Label("Open Monitor", systemImage: "text.magnifyingglass")
                        }
                        Button {
                            TerminalManager.shared.begin(for: machine)
                        } label: {
                            Label("Open Terminal", systemImage: "terminal")
                        }
                    }

                    Section {
                        Button {
                            openEdit = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button {
                            var newMachine = store.machineGroup[machine]
                            newMachine.id = .init()
                            store.machineGroup.insert(newMachine)
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                    }

                    Section {
                        Button {
                            let machine = store.machineGroup[machine]
                            UIBridge.sendPasteboard(str: machine.getCommand())
                        } label: {
                            Label("Copy Command", systemImage: "doc.on.doc")
                        }
                    }

                    Section {
                        Button {
                            UIBridge.requiresConfirmation(
                                message: "Are you sure you want to delete this machine?"
                            ) { confirmed in
                                if confirmed {
                                    store.machineGroup.delete(machine)
                                }
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Color.accentColor
                        .opacity(0.0001)
                }
                .offset(x: 0, y: 4)
            }
    }

    var contentView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "server.rack")
                HStack {
                    Text(store.machineGroup[machine].name)
                    Spacer()
                }
                .overlay(
                    Rectangle()
                        .cornerRadius(2)
                        .foregroundColor(redactedColor)
                        .expended()
                        .opacity(
                            store.machineRedacted.rawValue > 1 ? 1 : 0
                        )
                )
            }
            .font(.system(.headline, design: .rounded))
            HStack {
                Text(store.machineGroup[machine].remoteAddress)
                Spacer()
                HStack(spacing: 0) {
                    Spacer()
                    Text(store.machineGroup[machine].remotePort)
                }
                .frame(width: 75)
            }
            .font(.system(.footnote, design: .rounded))
            .overlay(
                Rectangle()
                    .cornerRadius(2)
                    .foregroundColor(redactedColor)
                    .expended()
                    .opacity(
                        store.machineRedacted.rawValue > 0 ? 1 : 0
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
                        store.machineGroup[machine]
                            .lastConnection
                            .formatted(date: .abbreviated, time: .omitted)
                    )
                    .lineLimit(1)
                    Text(
                        store.machineGroup[machine]
                            .lastBanner
                            .count > 0 ?
                            store.machineGroup[machine].lastBanner
                            : "Not Identified"
                    )
                    .lineLimit(1)
                    Text(
                        store.machineGroup[machine]
                            .comment
                            .count > 0 ?
                            store.machineGroup[machine].comment
                            : "No Comment"
                    )
                    .lineLimit(1)
                }
            }
            .font(.system(.subheadline, design: .rounded))
            .overlay(
                Rectangle()
                    .cornerRadius(2)
                    .foregroundColor(redactedColor)
                    .expended()
                    .opacity(
                        store.machineRedacted.rawValue > 1 ? 1 : 0
                    )
            )
            Divider()
            CopyableText(machine.uuidString)
                .font(.system(size: 8, weight: .light, design: .monospaced))
        }
        .animation(.interactiveSpring(), value: store.machineRedacted)
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            Color(UIColor.systemGray6)
                .roundedCorner()
        )
        .background(
            NavigationLink(isActive: $openEdit) {
                EditMachineView { machine }
            } label: {
                Group {}
            }
        )
    }
}

struct MachineElementView_Previews: PreviewProvider {
    static var previews: some View {
        MachineElementView(machine: UUID())
            .environmentObject(RayonStore.shared)
    }
}
