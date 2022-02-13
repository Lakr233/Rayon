//
//  PickMachineView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/4.
//

import RayonModule
import SwiftUI

struct PickMachineView: View {
    @StateObject var store = RayonStore.shared

    @Binding var selection: [RDMachine.ID]
    @State var rawSelection: [RDMachine.ID] = []

    init(selection: Binding<[RDMachine.ID]>) {
        _selection = selection
    }

    private var completion: (([RDMachine.ID]) -> Void)?

    /// MAKE SURE THIS VIEW IS NOT DISMISSABLE BY DRAG
    /// - Parameter completion: only called when touch checkmark button
    init(completion: @escaping (([RDMachine.ID]) -> Void)) {
        self.completion = completion
        _selection = Binding<[RDMachine.ID]> { [] } set: { _ in }
    }

    @Environment(\.presentationMode) var presentationMode

    var selectionFooter: String {
        rawSelection
            .map { store.machineGroup[$0].name }
            .joined(separator: " ")
    }

    var body: some View {
        List {
            Section {
                if rawSelection.isEmpty {
                    Label("Not Selected", systemImage: "questionmark.square.dashed")
                } else {
                    Label("\(rawSelection.count) Selected", systemImage: "server.rack")
                }
            } header: {
                Label("Selected Machine", systemImage: "arrow.right")
            } footer: {
                if !selectionFooter.isEmpty {
                    Text(selectionFooter)
                } else {
                    Text("<Not Available>")
                }
            }

            Section {
                if store.machineGroup.machines.isEmpty {
                    Label("No Machine Available", systemImage: "questionmark.square.dashed")
                } else {
                    ForEach(store.machineGroup.machines) { machine in
                        Button {
                            toggleSelection(for: machine.id)
                        } label: {
                            Label(machine.shortDescription(), systemImage: sysImage(for: machine))

//                            HStack(spacing: 5) {
//                                Image(systemName: sysImage(for: machine))
//                                    .frame(width: 20)
//                                Text(machine.shortDescription())
//                            }
                        }
//                        .disabled(machine.associatedIdentity == nil)
                    }
                }
            } header: {
                Label("Available Machines", systemImage: "square.stack.3d.down.forward")
            }

            Section {
                Button {
                    rawSelection = []
                } label: {
                    Label("Clear Selection", systemImage: "xmark")
                }
                .disabled(rawSelection.isEmpty)
            }
        }
        .navigationTitle("Pick Machine")
        .toolbar {
            ToolbarItem {
                Button {
                    presentationMode.wrappedValue.dismiss()
                    completion?(rawSelection)
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
            }
        }
        .onChange(of: rawSelection) { newValue in
            selection = newValue
        }
    }

    func sysImage(for machine: RDMachine) -> String {
//        if machine.associatedIdentity == nil {
//            return "person.fill.questionmark"
//        }
        if rawSelection.contains(machine.id) {
            return "circle.fill"
        }
        return "circle.dashed"
    }

    func toggleSelection(for mid: RDMachine.ID) {
        if let index = rawSelection.firstIndex(of: mid) {
            rawSelection.remove(at: index)
        } else {
            rawSelection.append(mid)
        }
    }
}

struct PickMachineView_Previews: PreviewProvider {
    static var previews: some View {
        createPreview { AnyView(
            PickMachineView { result in
                debugPrint(result)
            }
        ) }
    }
}
