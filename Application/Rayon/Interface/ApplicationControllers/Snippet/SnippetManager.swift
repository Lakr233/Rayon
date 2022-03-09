//
//  SnippetManager.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import CodeMirrorUI
import RayonModule
import SwiftUI

struct SnippetManager: View {
    @EnvironmentObject var store: RayonStore

    @State var searchText: String = ""
    @State var openAddSheet: Bool = false

    @State var selection: Set<RDSnippet.ID> = []
    @State var hoverSelection: RDSnippet.ID? = nil

    var itemSpacing: Double { UIBridge.itemSpacing }

    func sectionFor(snippets: [RDSnippet]) -> [String] {
        [String](Set<String>(
            snippets.map(\.group)
        )).sorted()
    }

    func searchResultFor(section: String) -> [RDSnippet] {
        if searchText.count == 0 {
            return store.snippetGroup
                .snippets
                .filter { $0.group == section }
        } else {
            return store.snippetGroup
                .snippets
                .filter { $0.group == section }
                .filter { $0.isQualifiedForSearch(text: searchText) }
        }
    }

    func sectionData() -> [String] {
        if searchText.count == 0 {
            return store.snippetGroup.sections
        }
        let all = store
            .snippetGroup
            .snippets
            .filter { $0.isQualifiedForSearch(text: searchText) }
        return sectionFor(snippets: all)
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
        .sheet(isPresented: $openAddSheet, onDismiss: nil) {
            EditSnippetSheetView(inEdit: nil)
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
        }
        .searchable(text: $searchText)
        .navigationTitle("Snippets - \(store.snippetGroup.count) available")
    }

    var collections: some View {
        Group {
            if store.snippetGroup.count == 0 {
                Text("No Snippet Available")
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

    var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 280, maximum: 500), spacing: itemSpacing)]
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
                    ForEach(searchResultFor(section: section)) { snippet in
                        SnippetView(snippet: snippet.id)
                            .overlay(
                                VStack {
                                    HStack(spacing: 4) {
                                        Spacer()
                                        SnippetFloatingPanelView(snippet: snippet.id)
                                    }
                                    Spacer()
                                }
                                .padding(4)
                                .opacity(hoverSelection == snippet.id ? 1 : 0)
                            )
                            .border(Color.gray, width: selection.contains(snippet.id) ? 0.5 : 0)
                            .border(Color.accentColor, width: hoverSelection == snippet.id ? 0.5 : 0)
                            .onTapGesture {
                                if selection.contains(snippet.id) {
                                    selection = selection
                                        .filter { $0 != snippet.id }
                                } else {
                                    selection.insert(snippet.id)
                                }
                            }
                            .onHover { hover in
                                if hover {
                                    hoverSelection = snippet.id
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
                store.snippetGroup.delete(selection)
            }
            selection = []
        }
    }
}
