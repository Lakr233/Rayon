//
//  PortForwardView.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/3/10.
//

import RayonModule
import SwiftUI

struct PortForwardManager: View {
    @EnvironmentObject var store: RayonStore
    @StateObject var backend = PortForwardBackend.shared

    var tableItems: [RDPortForward] {
        store
            .portForwardGroup
            .forwards
            .filter {
                if searchText.count == 0 {
                    return true
                }
                if $0.targetHost.lowercased().contains(searchText) {
                    return true
                }
                if String($0.targetPort).contains(searchText) {
                    return true
                }
                if String($0.bindPort).contains(searchText) {
                    return true
                }
                return false
            }
            .sorted(using: sortOrder)
    }

    @State var searchText: String = ""
    @State var selection: Set<RDPortForward.ID> = []
    @State var sortOrder: [KeyPathComparator<RDPortForward>] = []
    
    var startButtonCanWork: Bool {
        for sel in selection {
            if !backend.sessionExists(withPortForwardID: sel) {
                return true
            }
        }
        return false
    }
    
    var stopButtonCanWork: Bool {
        for sel in selection {
            if backend.sessionExists(withPortForwardID: sel) {
                return true
            }
        }
        return false
    }

    var body: some View {
        Group {
            if tableItems.isEmpty {
                Text("No Port Forward Available")
                    .expended()
            } else {
                table
            }
        }
        .requiresFrame()
        .toolbar {
            ToolbarItem {
                Button {
                    removeButtonTapped()
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(selection.count == 0)
            }
            ToolbarItem {
                Button {
                    duplicateButtonTapped()
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                .disabled(selection.count == 0)
            }
            ToolbarItem {
                Button {
                    store.portForwardGroup.insert(.init())
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
                    stopPortForward()
                } label: {
                    Label("Stop Select", systemImage: "stop.fill")
                }
                .disabled(selection.isEmpty)
                .disabled(!stopButtonCanWork)
            }
            ToolbarItem {
                Button {
                    startPortForward()
                } label: {
                    Label("Open Select", systemImage: "play.fill")
                }
                .disabled(selection.isEmpty)
                .disabled(!startButtonCanWork)
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("Port Forward - \(store.portForwardGroup.count) available")
    }

    var table: some View {
        Table(selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Action") { data in
                Button {
                    if backend.sessionExists(withPortForwardID: data.id) {
                        backend.endSession(withPortForwardID: data.id)
                    } else {
                        backend.createSession(withPortForwardID: data.id)
                    }
                } label: {
                    Text(backend.sessionExists(withPortForwardID: data.id) ? "Terminate" : "Open")
                }
            }
            .width(80)
            TableColumn("Status") { data in
                Text(backend.lastHint[data.id] ?? "Ready")
            }
            TableColumn("Forward Orientation") { data in
                Picker(selection: $store.portForwardGroup[data.id].forwardOrientation) {
                    ForEach(RDPortForward.ForwardOrientation.allCases, id: \.self) { acase in
                        Text(acase.rawValue)
                            .tag(acase)
                    }
                } label: {
                    if data.forwardOrientation == .listenLocal {
                        Image(systemName: "arrow.right")
                    } else if data.forwardOrientation == .listenRemote {
                        Image(systemName: "arrow.left")
                    } else {
                        Image(systemName: "questionmark")
                    }
                }
                .disabled(backend.sessionExists(withPortForwardID: data.id))
            }
            TableColumn("Forward Through Machine") { data in
                HStack {
                    Text(data.getMachineName() ?? "Not Selected")
                    Spacer()
                    Button {
                        DispatchQueue.global().async {
                            let selection = RayonUtil.selectOneMachine()
                            mainActor {
                                store.portForwardGroup[data.id].usingMachine = selection
                            }
                        }
                    } label: {
                        Text("...")
                    }
                    .disabled(backend.sessionExists(withPortForwardID: data.id))
                }
            }
            TableColumn("Bind Port", value: \.bindPort) { data in
                TextField("Bind Port", text: .init(get: {
                    String(data.bindPort)
                }, set: { str in
                    store.portForwardGroup[data.id].bindPort = Int(str) ?? 0
                }))
                .disabled(backend.sessionExists(withPortForwardID: data.id))
            }
            .width(65)
            TableColumn("Target Host", value: \.targetHost) { data in
                TextField("Host Address", text: $store.portForwardGroup[data.id].targetHost)
            }
            TableColumn("Target Port", value: \.targetPort) { data in
                TextField("Target Port", text: .init(get: {
                    String(data.targetPort)
                }, set: { str in
                    store.portForwardGroup[data.id].targetPort = Int(str) ?? 0
                }))
                .disabled(backend.sessionExists(withPortForwardID: data.id))
            }
            .width(65)
            TableColumn("Description") { data in
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(data.shortDescription())
                }
            }
        } rows: {
            ForEach(tableItems) { item in
                TableRow(item)
            }
        }
    }
    
    func removeButtonTapped() {
        UIBridge.requiresConfirmation(
            message: "Are you sure you want to remove \(selection.count) items?"
        ) { y in
            if y {
                for selected in selection {
                    store.portForwardGroup.delete(selected)
                    backend.endSession(withPortForwardID: selected)
                }
            }
        }
    }

    func duplicateButtonTapped() {
        UIBridge.requiresConfirmation(
            message: "Are you sure you want to duplicate \(selection.count) items?"
        ) { y in
            if y {
                for selected in selection {
                    var read = store.portForwardGroup[selected]
                    read.id = .init()
                    store.portForwardGroup.insert(read)
                }
            }
        }
    }

    func startPortForward() {
        for selected in selection {
            backend.createSession(withPortForwardID: selected)
        }
    }

    func stopPortForward() {
        for selected in selection {
            backend.endSession(withPortForwardID: selected)
        }
    }
}
