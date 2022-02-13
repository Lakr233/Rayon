//
//  SnippetView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/10.
//

import CodeMirrorUI
import RayonModule
import SwiftUI

struct SnippetView: View {
    let snippet: RDSnippet.ID
    @EnvironmentObject var store: RayonStore
    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    @State var openEditSheet: Bool = false

    var body: some View {
        contentView
            .contextMenu {
                Button {
                    let index = store
                        .snippetGroup
                        .snippets
                        .firstIndex { $0.id == snippet }
                    if let index = index {
                        store.snippetGroup.snippets.remove(at: index)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .background(
                Color.accentColor
                    .opacity(0.05)
                    .roundedCorner()
            )
            .sheet(isPresented: $openEditSheet, onDismiss: nil, content: {
                EditSnippetSheetView(inEdit: snippet)
            })
            .expended()
    }

    let editor = SCodeEditor()

    var contentView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: store.snippetGroup[snippet].getSFAvatar())
                    .font(.system(.title2, design: .rounded))
                VStack(spacing: 0) {
                    TextField("Snippet Name", text: $store.snippetGroup[snippet].name)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(.headline, design: .rounded))
                    TextField("No Comment", text: $store.snippetGroup[snippet].comment)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 8, weight: .regular, design: .rounded))
                }
            }
            Divider()
            Text(store.snippetGroup[snippet].code)
                .textSelection(.enabled)
                .font(.system(size: 10, weight: .light, design: .monospaced))
                .frame(height: 75)
            Divider()
            Text(snippet.uuidString)
                .textSelection(.enabled)
                .font(.system(size: 5, weight: .light, design: .monospaced))
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

struct SnippetFloatingPanelView: View {
    let snippet: RDSnippet.ID

    @EnvironmentObject var store: RayonStore

    @State var openEdit: Bool = false
    @State var openServerPicker: Bool = false

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
                chooseMachine()
            } label: {
                Image(systemName: "paperplane.fill")
                    .frame(width: 15)
            }
            .foregroundColor(.accentColor)
        }
        .sheet(isPresented: $openEdit, onDismiss: nil) {
            EditSnippetSheetView(inEdit: snippet)
        }
        .sheet(isPresented: $openServerPicker, onDismiss: nil, content: {
            MachinePickerView(onComplete: { machines in
                store.beginBatchScriptExecution(for: snippet, and: machines)
            }, allowSelectMany: true)
        })
    }

    func chooseMachine() {
        openServerPicker = true
    }

    func duplicateButtonTapped() {
        UIBridge.requiresConfirmation(
            message: "You are about to duplicate this item"
        ) { confirmed in
            guard confirmed else { return }
            let index = store
                .snippetGroup
                .snippets
                .firstIndex { $0.id == snippet }
            if let index = index {
                var read = store.snippetGroup.snippets[index]
                read.id = .init()
                store.snippetGroup.snippets.append(read)
            }
        }
    }

    func beginExecutionOn(machines: [RDMachine.ID]) {
        debugPrint("will execute on \(machines)")
    }

    func deleteButtonTapped() {
        UIBridge.requiresConfirmation(
            message: "You are about to delete this item"
        ) { confirmed in
            guard confirmed else { return }
            let index = store
                .snippetGroup
                .snippets
                .firstIndex { $0.id == snippet }
            if let index = index {
                store.snippetGroup.snippets.remove(at: index)
            }
        }
    }
}
