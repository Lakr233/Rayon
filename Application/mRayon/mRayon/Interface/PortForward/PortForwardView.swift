//
//  PortForwardView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/2.
//

import RayonModule
import SwiftUI

struct PortForwardView: View {
    @EnvironmentObject var store: RayonStore

    @State var openEditView: Bool = false

    @State var searchKey: String = ""

    var content: [RDPortForward.ID] {
        if searchKey.isEmpty {
            return store
                .portForwardGroup
                .forwards
                .map(\.id)
        }
        let searchText = searchKey.lowercased()
        return store
            .portForwardGroup
            .forwards
            .filter { object in
                if searchText.count == 0 {
                    return true
                }
                if object.targetHost.lowercased().contains(searchText) {
                    return true
                }
                if String(object.targetPort).contains(searchText) {
                    return true
                }
                if String(object.bindPort).contains(searchText) {
                    return true
                }
                return false
            }
            .map(\.id)
    }

    var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 280, maximum: 500), spacing: 10)]
    }

    var body: some View {
        Group {
            if store.portForwardGroup.forwards.isEmpty {
                PlaceholderView("No Forward Available", img: .connectionBroken)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("\(content.count) forward(s) available, tap for option.", systemImage: "person.3.fill")
                            .font(.system(.footnote, design: .rounded))
                        Divider()
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                            ForEach(content, id: \.self) { forwardId in
                                PortForwardElementView(forward: forwardId)
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
        .navigationTitle("Port Forward")
        .toolbar {
            ToolbarItem {
                Button {
                    openEditView = true
                } label: {
                    Label("Create Forward", systemImage: "plus")
                }
            }
        }
    }

    var navigationSheet: some View {
        Group {
            NavigationLink(isActive: $openEditView) {
                EditPortForwardView()
            } label: {
                Group {}
            }
        }
    }
}
