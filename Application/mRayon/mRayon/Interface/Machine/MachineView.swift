//
//  MachineView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/2.
//

import RayonModule
import SwiftUI

struct MachineView: View {
    @EnvironmentObject var store: RayonStore

    @State var openEditView: Bool = false

    @State var searchKey: String = ""

    var content: [RDMachine.ID] {
        if searchKey.isEmpty {
            return store
                .machineGroup
                .machines
                .map(\.id)
        }
        let key = searchKey.lowercased()
        return store
            .machineGroup
            .machines
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
            if store.machineGroup.machines.isEmpty {
                PlaceholderView("No Machine Available", img: .emptyWindow)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("\(content.count) machine(s) available, long press for option.", systemImage: "server.rack")
                            .font(.system(.footnote, design: .rounded))
                        Divider()
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                            ForEach(content, id: \.self) { identity in
                                MachineElementView(machine: identity)
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
        .navigationTitle("Machine")
        .toolbar {
            ToolbarItem {
                Button {
                    openEditView = true
                } label: {
                    Label("Create Machine", systemImage: "plus")
                }
            }
        }
    }

    var navigationSheet: some View {
        Group {
            NavigationLink(isActive: $openEditView) {
                EditMachineView()
            } label: {
                Group {}
            }
        }
    }
}

struct MachineView_Previews: PreviewProvider {
    static var previews: some View {
        createPreview {
            AnyView(MachineView())
        }
    }
}
