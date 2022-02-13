//
//  SnippetElementView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/3.
//

import RayonModule
import SwiftUI

struct SnippetElementView: View {
    @EnvironmentObject var store: RayonStore

    let identity: RDSnippet.ID

    @State var openEdit: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: store.snippetGroup[identity].getSFAvatar())
                    .font(.system(.subheadline, design: .rounded))
                    .frame(width: 20)
                Text(store.snippetGroup[identity].name)
                    .font(.system(.headline, design: .rounded))
                    .bold()
                Spacer()
            }
            Text(store.snippetGroup[identity].comment)
                .font(.system(.footnote, design: .rounded))
            Divider()
            VStack(spacing: 0) {
                Text(
                    store
                        .snippetGroup[identity]
                        .code
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                )
                .font(.system(.subheadline, design: .monospaced))
                Spacer()
            }
            .frame(height: 90)
            Divider()
            Text(identity.uuidString)
                .font(.system(size: 8, weight: .light, design: .rounded))
        }
        .padding()
        .background(
            Color(UIColor.systemGray6)
                .roundedCorner()
        )
        .background(
            NavigationLink(isActive: $openEdit) {
                EditSnippetView { identity }
            } label: {
                Group {}
            }
        )
        .onTapGesture {
            debugPrint(#function)
        }
        .overlay(
            Menu {
                Section {
                    Button {
                        let snippet = store.snippetGroup[identity]
                        guard !snippet.name.isEmpty,
                              !snippet.code.isEmpty
                        else {
                            return
                        }
                        RayonUtil.createExecuteFor(snippet: snippet)
                    } label: {
                        Label("Execute", systemImage: "paperplane")
                    }
                    Button {
                        let snippet = store.snippetGroup[identity]
                        guard !snippet.name.isEmpty,
                              !snippet.code.isEmpty
                        else {
                            return
                        }
                        UIBridge.sendPasteboard(str: snippet.code)
                    } label: {
                        Label("Copy Script", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
                Section {
                    Button {
                        openEdit = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button {
                        var newSnippet = store.snippetGroup[identity]
                        newSnippet.id = .init()
                        store.snippetGroup.insert(newSnippet)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                }
                Section {
                    Button {
                        delete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            } label: {
                Color.accentColor
                    .opacity(0.0001)
            }
            .offset(x: 0, y: 4)
        )
    }

    func delete() {
        UIBridge.requiresConfirmation(
            message: "Are you sure you want to delete this snippet?"
        ) { confirmed in
            if confirmed {
                store.snippetGroup.delete(identity)
            }
        }
    }
}

struct SnippetElementView_Previews: PreviewProvider {
    static var previews: some View {
        SnippetElementView(identity: UUID())
    }
}
