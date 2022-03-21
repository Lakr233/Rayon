//
//  MachineView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/10.
//

import RayonModule
import SwiftUI

struct MachineView: View {
    let machine: RDMachine.ID

    @EnvironmentObject var store: RayonStore

    @State var openEditSheet: Bool = false

    let redactedColor: Color = .accentColor

    var body: some View {
        contentView
            .contextMenu {
                Button {
                    store.machineGroup.delete(machine)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .background(
                Color.accentColor
                    .opacity(0.05)
                    .roundedCorner()
            )
            .sheet(isPresented: $openEditSheet) {
                MachineEditView(inEditWith: machine)
            }
            .onTapGesture(count: 2) {
                TerminalManager.shared.createSession(withMachineID: machine)
            }
    }

    var contentView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "server.rack")
                HStack {
                    TextField("Server Name", text: $store.machineGroup[machine].name)
                        .textFieldStyle(PlainTextFieldStyle())
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
                TextField("Server Address", text: $store.machineGroup[machine].remoteAddress)
                    .textFieldStyle(PlainTextFieldStyle())
                Spacer()
                TextField("Port", text: $store.machineGroup[machine].remotePort)
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
                    TextField("No Comment", text: $store.machineGroup[machine].comment)
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
                        store.machineRedacted.rawValue > 1 ? 1 : 0
                    )
            )
            .textSelection(.enabled)
            Divider()
            Text(machine.uuidString)
                .textSelection(.enabled)
                .font(.system(size: 5, weight: .light, design: .monospaced))
        }
        .animation(.interactiveSpring(), value: store.machineRedacted)
        .frame(maxWidth: .infinity)
        .padding()
    }
}
