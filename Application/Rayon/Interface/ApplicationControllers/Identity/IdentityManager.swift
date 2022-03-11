//
//  IdentityManager.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import RayonModule
import SwiftUI

struct IdentityManager: View {
    @EnvironmentObject var store: RayonStore

    var tableItems: [RDIdentity] {
        store
            .identityGroup
            .identities
            .filter {
                if searchText.count == 0 {
                    return true
                }
                if $0.username.lowercased().contains(searchText) {
                    return true
                }
                if $0.comment.lowercased().contains(searchText) {
                    return true
                }
                if $0.group.lowercased().contains(searchText) {
                    return true
                }
                return false
            }
            .sorted(using: sortOrder)
    }

    @State var searchText: String = ""
    @State var openCreateSheet: Bool = false
    @State var selection: Set<RDIdentity.ID> = []
    @State var sortOrder: [KeyPathComparator<RDIdentity>] = [
        .init(\.username, order: SortOrder.forward),
    ]
    @State var editSelection: RDIdentity.ID? = nil

    var body: some View {
        Group {
            if tableItems.count > 0 {
                table
            } else {
                Text("No Identity Available")
                    .expended()
            }
        }
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
                    editSelection = selection.first
                    openCreateSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .disabled(selection.count == 0)
            }
//            ToolbarItem {
//                Button {} label: {
//                    Label("Upload", systemImage: "arrow.up")
//                }
//                .disabled(selection.count == 0)
//            }
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
                    openCreateSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .keyboardShortcut(KeyboardShortcut(
                    .init(unicodeScalarLiteral: "n"),
                    modifiers: .command
                ))
            }
        }
        .background(sheetEnter.hidden())
        .searchable(text: $searchText)
        .navigationTitle("Identities - \(store.identityGroup.count) available")
    }

    var table: some View {
        Table(selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Username", value: \.username) { data in
                TextField("", text: $store.identityGroup[data.id].username)
            }
            TableColumn("Auto", value: \.authenticAutomatically, comparator: BoolComparator()) { data in
                Toggle("Auto", isOn: $store.identityGroup[data.id].authenticAutomatically)
                    .labelsHidden()
            }
            .width(50)
            TableColumn("Use Keys") { data in
                Text(data.getKeyType())
            }
            TableColumn("Last Used", value: \.lastRecentUsed) { data in
                if data.lastRecentUsed.timeIntervalSince1970 == 0 {
                    Text("Never")
                } else {
                    Text(
                        data
                            .lastRecentUsed
                            .formatted()
                    )
                }
            }
            TableColumn("Group", value: \.group) { data in
                TextField("Default", text: $store.identityGroup[data.id].group)
            }
            TableColumn("Comment", value: \.comment) { data in
                TextField("", text: $store.identityGroup[data.id].comment)
            }
        } rows: {
            ForEach(tableItems) { item in
                TableRow(item)
            }
        }
    }

    var sheetEnter: some View {
        Group {}
            .sheet(isPresented: $openCreateSheet) {
                editSelection = nil
            } content: {
                EditIdentityManager(selection: $editSelection)
            }
    }

    func removeButtonTapped() {
        UIBridge.requiresConfirmation(
            message: "You are about to remove \(selection.count) items"
        ) { confirmed in
            guard confirmed else { return }
            for selection in selection {
                store.identityGroup.delete(selection)
            }
            selection = []
        }
    }

    func duplicateButtonTapped() {
        UIBridge.requiresConfirmation(
            message: "You are about to duplicate \(selection.count) items"
        ) { confirmed in
            guard confirmed else { return }
            for selection in selection {
                var item = store.identityGroup[selection]
                item.id = UUID()
                store.identityGroup.insert(item)
            }
            selection = []
        }
    }
}
