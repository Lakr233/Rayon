//
//  MachinePickerView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/12.
//

import RayonModule
import SwiftUI

struct MachinePickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: RayonStore

    let onComplete: ([RDIdentity.ID]) -> Void
    let allowSelectMany: Bool

    @State var currentSelection: Set<RDIdentity.ID> = []
    @State var hoverFocus: RDIdentity.ID?

    var body: some View {
        SheetTemplate.makeSheet(
            title: "Select Machine",
            body: AnyView(sheetBody)
        ) { confirmed in
            var shouldDismiss = false
            defer { if shouldDismiss { presentationMode.wrappedValue.dismiss() } }
            if confirmed {
                onComplete([RDIdentity.ID](currentSelection))
            } else {
                onComplete([])
            }
            shouldDismiss = true
        }
    }

    var sheetBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(store.machineGroup.machines) { machine in
                    ServerPreviewBanner(machine: machine.id)
                        .padding(10)
                        .background(
                            Color.accentColor
                                .opacity(currentSelection.contains(machine.id) ? 0.1 : 0)
                                .roundedCorner()
                                .border(
                                    Color.gray.opacity(0.5),
                                    width: hoverFocus == machine.id ? 0.5 : 0
                                )
                        )
                        .overlay(
                            Color.accentColor.opacity(0.001) // tap area
                        )
                        .onTapGesture {
                            trySelect(with: machine.id)
                        }
                        .onHover { hover in
                            if hover {
                                hoverFocus = machine.id
                            } else {
                                hoverFocus = nil
                            }
                        }
                }
            }
        }
        .frame(maxHeight: 500)
        .requiresSheetFrame()
    }

    func trySelect(with machine: RDMachine.ID) {
        if currentSelection.contains(machine) {
            currentSelection.remove(machine)
        } else {
            if allowSelectMany {
                currentSelection.insert(machine)
            } else {
                currentSelection = [machine]
            }
        }
    }

    struct ServerPreviewBanner: View {
        @EnvironmentObject var store: RayonStore

        let machine: RDMachine.ID

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "server.rack")
                    HStack {
                        Text(store.machineGroup[machine].name)
                            .textFieldStyle(PlainTextFieldStyle())
                        Spacer()
                    }
                }
                .font(.system(.headline, design: .rounded))
                Divider()
                HStack {
                    Text("Address: " + store.machineGroup[machine].remoteAddress)
                        .textFieldStyle(PlainTextFieldStyle())
                    Spacer()
                    Text(store.machineGroup[machine].remotePort)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(PlainTextFieldStyle())
                        .frame(width: 50)
                }
                .font(.system(.footnote, design: .monospaced)) // "Address: ".count == "Comment: ".count
                Text(store.machineGroup[machine].comment.count > 0 ? "Comment: \(store.machineGroup[machine].comment)" : "Comment: Not Available")
                    .font(.system(.footnote, design: .monospaced))
            }
        }
    }
}
