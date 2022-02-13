//
//  BatchSnippetSidebarView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/13.
//

import SwiftUI

struct BatchSnippetSidebarView: View {
    @EnvironmentObject var context: BatchSnippetExecContext

    var body: some View {
        List {
            Section("Control") {
                NavigationLink {
                    BatchExecMainView()
                } label: {
                    Label("Overview", systemImage: "forward.end")
                }
            }
            Section("Individual") {
                ForEach(context.machines, id: \.self) { machine in
                    NavigationLink {
                        BatchTerminalView(machine: machine)
                    } label: {
                        Label(context.names[machine] ?? "Unknown Name", systemImage: "forward.end")
                    }
                }
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
}
