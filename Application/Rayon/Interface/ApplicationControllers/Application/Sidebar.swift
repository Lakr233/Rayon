//
//  Sidebar.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/8.
//

import RayonModule
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: RayonStore
    @EnvironmentObject var terminalManager: TerminalManager

    @State var openServerSelector: Bool = false

    var body: some View {
        List {
            NavigationLink {
                WelcomeView()
            } label: {
                Label("Welcome", systemImage: "sun.min.fill")
            }
            manager
            session
            recent
        }
        .navigationTitle("Rayon")
        .frame(minWidth: 200)
    }

    var manager: some View {
        Section("Manager") {
            NavigationLink {
                MachineManagerView()
            } label: {
                Label("Server", systemImage: "server.rack")
            }
            .badge(store.machineGroup.count)
            NavigationLink {
                IdentityManager()
            } label: {
                Label("Identity", systemImage: "person.fill")
            }
            .badge(store.identityGroup.count)
            NavigationLink {
                SnippetManager()
            } label: {
                Label("Snippet", systemImage: "arrow.right.doc.on.clipboard")
            }
            .badge(store.snippetGroup.count)
            NavigationLink {
                PortForwardManager()
            } label: {
                Label("Port Forward", systemImage: "arrowshape.turn.up.right.circle.fill")
            }
            .badge(store.portForwardGroup.count)
            NavigationLink {
                SettingView()
            } label: {
                Label("Setting", systemImage: "gearshape.fill")
            }
        }
    }

    var session: some View {
        Section("Session") {
            if terminalManager.sessionContexts.count == 0 {
                Button {} label: {
                    HStack {
                        Label("No Session", systemImage: "app.dashed")
                        Spacer()
                    }
                    .background(Color.accentColor.opacity(0.0001))
                }
                .buttonStyle(PlainButtonStyle())
                .expended()
            } else {
                ForEach(terminalManager.sessionContexts) { context in
                    NavigationLink {
                        TerminalView(context: context)
                    } label: {
                        if context.remoteType == .machine {
                            Label(context.machine.name, systemImage: "terminal")
                        } else {
                            Label(context.command?.command ?? "?", systemImage: "text.and.command.macwindow")
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button {
                            if terminalManager.sessionAlive(forContext: context.id) {
                                UIBridge.requiresConfirmation(
                                    message: "Terminal session still alive, are you sure you want to terminate?"
                                ) { confirmed in
                                    if confirmed {
                                        terminalManager.closeSession(withContextID: context.id)
                                    }
                                }
                            } else {
                                terminalManager.closeSession(withContextID: context.id)
                            }
                        } label: {
                            Label("Close Connection", image: "trash")
                        }
                    }
                }
                Button {
                    UIBridge.requiresConfirmation(
                        message: "Are you sure you want to stop all session?")
                    { confirmed in
                            guard confirmed else {
                                return
                            }
                            terminalManager.closeAll()
                        }
                } label: {
                    HStack {
                        Label("Stop All", systemImage: "trash")
                        Spacer()
                    }
                    .background(Color.accentColor.opacity(0.0001))
                }
                .buttonStyle(PlainButtonStyle())
                .expended()
            }
            Button {
                openServerSelector = true
            } label: {
                HStack {
                    Label("Batch Startup", systemImage: "wind")
                    Spacer()
                }
                .background(Color.accentColor.opacity(0.0001))
            }
            .sheet(isPresented: $openServerSelector, onDismiss: nil, content: {
                MachinePickerView(onComplete: { machines in
                    for machine in machines {
                        terminalManager.createSession(withMachineID: machine)
                    }
                }, allowSelectMany: true)
            })
            .buttonStyle(PlainButtonStyle())
            .expended()
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
                        Label("No Recent", systemImage: "arrow.counterclockwise")
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .expended()
            }
        }
    }

    func recentButton(for command: SSHCommandReader) -> some View {
        Button {
            UIBridge.requiresConfirmation(
                message: "Open connection with \(command.command)?"
            ) { confirmed in
                if confirmed {
                    terminalManager.createSession(withCommand: command)
                }
            }
        } label: {
            HStack {
                Label(command.command, systemImage: "rectangle.dashed.and.paperclip")
                Spacer()
            }
            .background(Color.accentColor.opacity(0.0001))
        }
        .contextMenu {
            Button {
                UIBridge.sendPasteboard(str: command.command)
            } label: {
                Label("Copy Command", systemImage: "doc.on.doc")
            }
            Button {
                store.recentRecord = store.recentRecord
                    .filter { $0.id != command.command }
            } label: {
                Label("Delete Record", systemImage: "trash")
            }
            .background(Color.accentColor.opacity(0.0001))
        }
        .buttonStyle(PlainButtonStyle())
        .expended()
    }

    func recentButton(for machine: RDMachine.ID) -> some View {
        Group {
            if store.machineGroup[machine].isNotPlaceholder() {
                Button {
                    UIBridge.requiresConfirmation(
                        message: "Open connection to \(store.machineGroup[machine].name)?"
                    ) { confirmed in
                        if confirmed {
                            terminalManager.createSession(withMachineID: machine)
                        }
                    }
                } label: {
                    HStack {
                        Label(store.machineGroup[machine].name, systemImage: "rectangle.and.paperclip")
                        Spacer()
                    }
                    .background(Color.accentColor.opacity(0.0001))
                }
                .buttonStyle(PlainButtonStyle())
                .expended()
                .contextMenu {
                    Button {
                        UIBridge.sendPasteboard(str: store.machineGroup[machine].getCommand())
                    } label: {
                        Label("Copy Command", systemImage: "doc.on.doc")
                    }
                    Button {
                        store.recentRecord = store.recentRecord
                            .filter { $0.id != machine.uuidString }
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
            message: "Are you sure you want to clear recent record?"
        ) { confirmed in
            guard confirmed else { return }
            store.recentRecord = []
        }
    }
}
