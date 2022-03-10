//
//  SidebarView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/2.
//

import RayonModule
import SwiftUI
import SwiftUIPolyfill

struct SidebarView: View {
    @EnvironmentObject var store: RayonStore

    @StateObject var monitorManager = MonitorManager.shared
    @StateObject var terminalManager = TerminalManager.shared

    var body: some View {
        NavigationView {
            sidebar
            WelcomeView()
        }
    }

    var sidebar: some View {
        List {
            app
            monitor
            terminals

            if store.storeRecent {
                recent
            }
//            portForward
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Rayon")
    }

    var app: some View {
        Section("App") {
            NavigationLink {
                WelcomeView()
            } label: {
                Label("Connect", systemImage: "paperplane")
            }
            NavigationLink {
                MachineView()
            } label: {
                Label("Machine", systemImage: "server.rack")
            }
            NavigationLink {
                IdentityView()
            } label: {
                Label("Identity", systemImage: "person")
            }
            NavigationLink {
                SnippetView()
            } label: {
                Label("Snippet", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            NavigationLink {
                SettingView()
            } label: {
                Label("Setting", systemImage: "gear")
            }
        }
    }

    var recent: some View {
        Section("Recent") {
            if store.recentRecord.count > 0 {
                ForEach(store.recentRecord) { record in
                    switch record {
                    case let .command(command): recentButton(for: command)
                    case let .machine(machine): recentButton(for: machine)
                    }
                }
                Button {
                    clearRecentTapped()
                } label: {
                    HStack {
                        Label("Clear Recent", systemImage: "trash")
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .expended()
            } else {
                Button {} label: {
                    HStack {
                        Label("No Recent", systemImage: "square.dashed")
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .expended()
            }
        }
    }

    var monitor: some View {
        Section("Monitor") {
            if monitorManager.monitors.isEmpty {
                Button {} label: {
                    HStack {
                        Label("No Session", systemImage: "square.dashed")
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .expended()
            } else {
                ForEach(monitorManager.monitors) { context in
                    NavigationLink {
                        MonitorView(context: context)
                    } label: {
                        Label(context.title, systemImage: "text.magnifyingglass")
                    }
                    .swipeActions(
                        trailing: [
                            SwipeActionButton(
                                text: "Delete", icon: "trash",
                                action: {
                                    monitorManager.end(for: context.id)
                                },
                                tint: .red
                            ),
                        ])
                }
            }
        }
    }

    var terminals: some View {
        Section("Terminals") {
            if terminalManager.terminals.isEmpty {
                Button {} label: {
                    HStack {
                        Label("No Session", systemImage: "square.dashed")
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .expended()
            } else {
                ForEach(terminalManager.terminals) { context in
                    NavigationLink {
                        TerminalView(context: context)
                    } label: {
                        Label(context.title, systemImage: "terminal")
                    }
                    .swipeActions(
                        trailing: [
                            SwipeActionButton(
                                text: "Delete", icon: "trash",
                                action: {
                                    terminalManager.end(for: context.id)
                                },
                                tint: .red
                            ),
                        ])
                }
            }
        }
    }

    var portForward: some View {
        Section("Port Forward") {
            Button {} label: {
                HStack {
                    Label("No Session", systemImage: "square.dashed")
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            .expended()
        }
    }

    func recentButton(for command: SSHCommandReader) -> some View {
        func delete() {
            store.recentRecord = store.recentRecord
                .filter { $0.id != command.command }
        }
        return Button {
            TerminalManager.shared.begin(for: command)
        } label: {
            HStack {
                Label(command.command, systemImage: "rectangle.dashed.and.paperclip")
                Spacer()
            }
            .background(Color.accentColor.opacity(0.0001))
        }
        .swipeActions(
            trailing: [
                SwipeActionButton(
                    text: "Delete", icon: "trash",
                    action: {
                        delete()
                    },
                    tint: .red
                ),
            ])
        .contextMenu {
            Button {
                UIBridge.sendPasteboard(str: command.command)
            } label: {
                Label("Copy Command", systemImage: "doc.on.doc")
            }
            Button {
                delete()
            } label: {
                Label("Delete Record", systemImage: "trash")
            }
            .background(Color.accentColor.opacity(0.0001))
        }
        .buttonStyle(PlainButtonStyle())
        .expended()
    }

    func recentButton(for machine: RDMachine.ID) -> some View {
        func delete() {
            store.recentRecord = store.recentRecord
                .filter { $0.id != machine.uuidString }
        }
        return Group {
            if store.machineGroup[machine].isNotPlaceholder() {
                Button {
                    TerminalManager.shared.begin(for: machine)
                } label: {
                    HStack {
                        Label(store.machineGroup[machine].name, systemImage: "rectangle.and.paperclip")
                        Spacer()
                    }
                    .background(Color.accentColor.opacity(0.0001))
                }
                .buttonStyle(PlainButtonStyle())
                .expended()
                .swipeActions(
                    trailing: [
                        SwipeActionButton(
                            text: "Delete", icon: "trash",
                            action: {
                                delete()
                            },
                            tint: .red
                        ),
                    ])
                .contextMenu {
                    Button {
                        UIBridge.sendPasteboard(str: store.machineGroup[machine].getCommand())
                    } label: {
                        Label("Copy Command", systemImage: "doc.on.doc")
                    }
                    Button {
                        delete()
                    } label: {
                        Label("Delete Record", systemImage: "trash")
                    }
                }
            } else {
                Button {} label: {
                    HStack {
                        Label("[deleted]", systemImage: "square.dashed")
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .expended()
            }
        }
    }

    func clearRecentTapped() {
        UIBridge.requiresConfirmation(
            message: "Are you sure you want to clear recent?"
        ) { confirmed in
            guard confirmed else { return }
            store.recentRecord = []
        }
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView()
            .previewDevice(PreviewDevice(rawValue: "iPad mini (6th generation)"))
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
