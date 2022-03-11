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

    var body: some View {
        List {
            NavigationLink {
                WelcomeView().requiresFrame()
            } label: {
                Label("Welcome", systemImage: "sun.min.fill")
            }
            manager
            session
            if store.storeRecent { recent }
        }
        .navigationTitle("Rayon")
        .frame(minWidth: 200)
    }

    var manager: some View {
        Section("Manager") {
            NavigationLink {
                MachineManagerView().requiresFrame()
            } label: {
                Label("Server", systemImage: "server.rack")
            }
            .badge(store.machineGroup.count)
            NavigationLink {
                IdentityManager().requiresFrame()
            } label: {
                Label("Identity", systemImage: "person.fill")
            }
            .badge(store.identityGroup.count)
            NavigationLink {
                SnippetManager().requiresFrame()
            } label: {
                Label("Snippet", systemImage: "arrow.right.doc.on.clipboard")
            }
            .badge(store.snippetGroup.count)
            NavigationLink {
                PortForwardManager().requiresFrame()
            } label: {
                Label("Port Forward", systemImage: "arrowshape.turn.up.right.circle.fill")
            }
            .badge(store.portForwardGroup.count)
            NavigationLink {
                SettingView().requiresFrame()
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
                        TerminalView(context: context).requiresFrame()
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
                DispatchQueue.global().async {
                    let machines = RayonUtil.selectMachine(allowMany: true)
                    mainActor {
                        for machine in machines {
                            terminalManager.createSession(withMachineID: machine)
                        }
                    }
                }
            } label: {
                HStack {
                    Label("Batch Startup", systemImage: "wind")
                    Spacer()
                }
                .background(Color.accentColor.opacity(0.0001))
            }
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
