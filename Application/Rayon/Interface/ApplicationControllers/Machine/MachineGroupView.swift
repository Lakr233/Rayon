//
//  MachineGroupView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import RayonModule
import SwiftUI

struct MachineGroupView: View {
    @EnvironmentObject var store: RayonStore

    @State var searchText: String = ""
    @State var openAddSheet: Bool = false

    @State var selection: Set<RDMachine.ID> = []
    @State var hoverSelection: RDMachine.ID? = nil

    var itemSpacing: Double { UIBridge.itemSpacing }

    func sectionFor(machines: [RDMachine]) -> [String] {
        [String](Set<String>(
            machines.map(\.group)
        )).sorted()
    }

    func searchResultFor(section: String) -> [RDMachine] {
        if searchText.count == 0 {
            return store.machineGroup
                .machines
                .filter { $0.group == section }
        } else {
            return store.machineGroup
                .machines
                .filter { $0.group == section }
                .filter { $0.isQualifiedForSearch(text: searchText) }
        }
    }

    func sectionData() -> [String] {
        if searchText.count == 0 {
            return store.machineGroup.sections
        }
        let all = store
            .machineGroup
            .machines
            .filter { $0.isQualifiedForSearch(text: searchText) }
        return sectionFor(machines: all)
    }

    var body: some View {
        Group {
            collections
                .requiresFrame()
                .animation(.interactiveSpring(), value: hoverSelection)
                .animation(.interactiveSpring(), value: selection)
                .animation(.interactiveSpring(), value: store.machineGroup)
                .padding()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    removeButtonTapped()
                } label: {
                    Label("Delete", systemImage: "minus")
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(selection.count == 0)
            }
            ToolbarItem {
                Button {
                    openAddSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .keyboardShortcut(KeyboardShortcut(
                    .init(unicodeScalarLiteral: "n"),
                    modifiers: .command
                ))
            }
            ToolbarItem {
                Button {
                    switch store.machineRedacted {
                    case .none:
                        store.machineRedacted = .sensitive
                    case .sensitive:
                        store.machineRedacted = .all
                    case .all:
                        store.machineRedacted = .none
                    }

                } label: {
                    switch store.machineRedacted {
                    case .none:
                        Label("Redact Machines", systemImage: "eyes")
                    case .sensitive:
                        Label("Redact Machines", systemImage: "eyes.inverse")
                    case .all:
                        Label("Redact Machines", systemImage: "eye.trianglebadge.exclamationmark.fill")
                    }
                }
                .keyboardShortcut(KeyboardShortcut(
                    .init(unicodeScalarLiteral: "h"),
                    modifiers: .option
                ))
            }
        }
        .background(sheetEnter.hidden())
        .searchable(text: $searchText)
        .navigationTitle("Machines - \(store.machineGroup.machines.count) available")
    }

    var sheetEnter: some View {
        Group {}
            .sheet(isPresented: $openAddSheet, onDismiss: nil) {
                MachineCreateView(requiresDismissAction: true)
            }
    }

    var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 280, maximum: 500), spacing: itemSpacing)]
    }

    var collections: some View {
        Group {
            if store.machineGroup.count == 0 {
                Text("No Server Available")
                    .expended()
            } else {
                ScrollView {
                    eachCollection
                        .background(
                            Color.accentColor
                                .opacity(0.001)
                                .onTapGesture {
                                    selection = []
                                }
                        )
                        .padding(20)
                }
                .padding(-20)
            }
        }
    }

    var eachCollection: some View {
        VStack(alignment: .leading, spacing: itemSpacing) {
            ForEach(sectionData(), id: \.self) { section in
                HStack {
                    Text(
                        section.count > 0
                            ? section : "Ungrouped Section - (Default)"
                    )
                    Spacer()
                }
                .font(.system(.headline, design: .rounded))
                LazyVGrid(columns: columns, alignment: .leading, spacing: itemSpacing) {
                    ForEach(searchResultFor(section: section)) { machine in
                        MachineView(machine: machine.id)
                            .overlay(
                                VStack {
                                    HStack(spacing: 4) {
                                        Spacer()
                                        MachineActionView(machine: machine.id)
                                    }
                                    Spacer()
                                }
                                .padding(4)
                                .opacity(hoverSelection == machine.id ? 1 : 0)
                            )
                            .border(Color.gray, width: selection.contains(machine.id) ? 0.5 : 0)
                            .border(Color.accentColor, width: hoverSelection == machine.id ? 0.5 : 0)
                            .onTapGesture {
                                if selection.contains(machine.id) {
                                    selection = selection
                                        .filter { $0 != machine.id }
                                } else {
                                    selection.insert(machine.id)
                                }
                            }
                            .onHover { hover in
                                if hover {
                                    hoverSelection = machine.id
                                } else {
                                    hoverSelection = nil
                                }
                            }
                    }
                }
            }
            Divider()
            Label("In place editing is supported on some fields~", systemImage: "pencil.circle.fill")
                .font(.system(.footnote, design: .rounded))
        }
    }

    func removeButtonTapped() {
        UIBridge.requiresConfirmation(
            message: "You are about to remove \(selection.count) items"
        ) { confirmed in
            guard confirmed else { return }
            for selection in selection {
                let index = store
                    .machineGroup
                    .machines
                    .firstIndex { $0.id == selection }
                if let index = index {
                    store.machineGroup.machines.remove(at: index)
                }
                store.cleanRecentIfNeeded()
            }
            selection = []
        }
    }
}
