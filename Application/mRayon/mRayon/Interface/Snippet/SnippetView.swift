//
//  SnippetView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/2.
//

import RayonModule
import SwiftUI

struct SnippetView: View {
    @EnvironmentObject var store: RayonStore

    @State var openEditView: Bool = false

    @State var searchKey: String = ""

    var content: [RDIdentity.ID] {
        if searchKey.isEmpty {
            return store
                .snippetGroup
                .snippets
                .map(\.id)
        }
        let key = searchKey.lowercased()
        return store
            .snippetGroup
            .snippets
            .filter { object in
                object.isQualifiedForSearch(text: key)
            }
            .map(\.id)
    }

    var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 280, maximum: 500), spacing: 10)]
    }

    var body: some View {
        Group {
            if store.snippetGroup.snippets.isEmpty {
                PlaceholderView("No Snippet Available", img: .ghost)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("\(content.count) snippet(s) available, tap for option.", systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.system(.footnote, design: .rounded))
                        Divider()
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                            ForEach(content, id: \.self) { snippetId in
                                SnippetElementView(identity: snippetId)
                            }
                        }
                        Divider()
                        Label("EOF", systemImage: "text.append")
                            .font(.system(.footnote, design: .rounded))
                    }
                    .padding()
                }
                .searchable(text: $searchKey)
            }
        }
        .animation(.interactiveSpring(), value: content)
        .animation(.interactiveSpring(), value: searchKey)
        .background(navigationSheet)
        .navigationTitle("Snippet")
        .toolbar {
            ToolbarItem {
                Button {
                    openEditView = true
                } label: {
                    Label("Create Snippet", systemImage: "plus")
                }
            }
        }
    }

    var navigationSheet: some View {
        Group {
            NavigationLink(isActive: $openEditView) {
                EditSnippetView()
            } label: {
                Group {}
            }
        }
    }
}

struct SnippetView_Previews: PreviewProvider {
    static var previews: some View {
        createPreview {
            AnyView(SnippetView())
        }
    }
}
