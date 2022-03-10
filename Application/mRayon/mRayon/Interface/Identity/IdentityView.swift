//
//  IdentityView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/2.
//

import RayonModule
import SwiftUI
import SwiftUIPolyfill

struct IdentityView: View {
    @EnvironmentObject var store: RayonStore

    @State var openEditView: Bool = false

    @State var searchKey: String = ""

    var content: [RDIdentity.ID] {
        if searchKey.isEmpty {
            return store
                .identityGroup
                .identities
                .map(\.id)
        }
        let key = searchKey.lowercased()
        return store
            .identityGroup
            .identities
            .filter { object in
                if object.username.lowercased().contains(key) {
                    return true
                }
                if object.comment.lowercased().contains(key) {
                    return true
                }
                if object.group.lowercased().contains(key) {
                    return true
                }
                return false
            }
            .map(\.id)
    }

    var body: some View {
        Group {
            if store.identityGroup.identities.isEmpty {
                PlaceholderView("No Identity Available", img: .fileLock)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("\(content.count) identity/identities available, long press for option.", systemImage: "person.3.fill")
                            .font(.system(.footnote, design: .rounded))
                        Divider()
                        ForEach(content, id: \.self) { identityId in
                            IdentityElementView(identity: identityId)
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
        .navigationTitle("Identity")
        .toolbar {
            ToolbarItem {
                Button {
                    openEditView = true
                } label: {
                    Label("Create Identity", systemImage: "plus")
                }
            }
        }
    }

    var navigationSheet: some View {
        Group {
            NavigationLink(isActive: $openEditView) {
                EditIdentityView()
            } label: {
                Group {}
            }
        }
    }
}

struct IdentityView_Previews: PreviewProvider {
    static var previews: some View {
        createPreview {
            AnyView(IdentityView())
        }
    }
}
