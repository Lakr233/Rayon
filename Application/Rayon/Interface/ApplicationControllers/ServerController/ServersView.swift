//
//  ServersView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import SwiftUI

struct ServersView: View {
    @EnvironmentObject var store: RayonStore

    @State var searchText: String = ""
    @State var openAddSheet: Bool = false

    @State var selection: Set<RDRemoteMachine.ID> = []
    @State var hoverSelection: RDRemoteMachine.ID? = nil

    var itemSpacing: Double { UIBridge.itemSpacing }

    func sectionFor(machines: [RDRemoteMachine]) -> [String] {
        [String](Set<String>(
            machines.map(\.group)
        )).sorted()
    }

    func searchResultFor(section: String) -> [RDRemoteMachine] {
        if searchText.count == 0 {
            return store.remoteMachines
                .machines
                .filter { $0.group == section }
        } else {
            return store.remoteMachines
                .machines
                .filter { $0.group == section }
                .filter { $0.isQualifiedForSearch(text: searchText) }
        }
    }

    func sectionData() -> [String] {
        if searchText.count == 0 {
            return store.remoteMachines.sections
        }
        let all = store
            .remoteMachines
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
                .animation(.interactiveSpring(), value: store.remoteMachines)
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
                    switch store.remoteMachineRedactedLevel {
                    case .none:
                        store.remoteMachineRedactedLevel = .sensitive
                    case .sensitive:
                        store.remoteMachineRedactedLevel = .all
                    case .all:
                        store.remoteMachineRedactedLevel = .none
                    }

                } label: {
                    switch store.remoteMachineRedactedLevel {
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
        .navigationTitle("Machines - \(store.remoteMachines.machines.count) available")
    }

    var sheetEnter: some View {
        Group {}
            .sheet(isPresented: $openAddSheet, onDismiss: nil) {
                CreateServerView(requiresDismissAction: true)
            }
    }

    var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 280, maximum: 500), spacing: itemSpacing)]
    }

    var collections: some View {
        Group {
            if store.remoteMachines.count == 0 {
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
                        RemoteMachineView(machine: machine.id)
                            .overlay(
                                VStack {
                                    HStack(spacing: 4) {
                                        Spacer()
                                        RemoteMachineFloatingPanelView(machine: machine.id)
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
                    .remoteMachines
                    .machines
                    .firstIndex { $0.id == selection }
                if let index = index {
                    store.remoteMachines.machines.remove(at: index)
                }
                store.cleanRecentIfNeeded()
            }
            selection = []
        }
    }
}
