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
    @SceneStorage("sidebar.selection") var sidebarSelection: String = ""
    @State var selection: NavigationItem? = nil

    @StateObject var sessionManager = RDSessionManager.shared

    @State var openServerSelector: Bool = false

    enum NavigationItem: String {
        case quickConnect
        case servers
        case identities
        case snippets
    }

    var body: some View {
        List(selection: $selection) {
            NavigationLink {
                WelcomeView()
            } label: {
                Label("Welcome", systemImage: "sun.min.fill")
            }
            .tag(NavigationItem.quickConnect)
            Section("Manager") {
                NavigationLink {
                    MachineGroupView()
                } label: {
                    Label("Server", systemImage: "server.rack")
                }
                .badge(store.machineGroup.count)
                .tag(NavigationItem.servers)
                NavigationLink {
                    IdentitiesView()
                } label: {
                    Label("Identity", systemImage: "key.fill")
                }
                .badge(store.identityGroup.count)
                .tag(NavigationItem.identities)
                NavigationLink {
                    SnippetsView()
                } label: {
                    Label("Snippet", systemImage: "arrow.right.doc.on.clipboard")
                }
                .badge(store.snippetGroup.count)
                .tag(NavigationItem.snippets)
            }
            Section("Session") {
                if sessionManager.remoteSessions.count == 0 {
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
                    ForEach(sessionManager.remoteSessions) { session in
                        Button {
                            store.requestSessionInterface(session: session.id)
                        } label: {
                            HStack {
                                Label(session.context.machine.name, systemImage: "play.fill")
                                Spacer()
                            }
                            .background(Color.accentColor.opacity(0.001))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button {
                                UIBridge.requiresConfirmation(
                                    message: "This will close all sub-channel associated to this session"
                                ) { confirmed in
                                    if confirmed {
                                        store.terminateSession(with: session.id)
                                    }
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
                                for session in sessionManager.remoteSessions {
                                    store.terminateSession(with: session.id)
                                }
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
                            store.beginSessionStartup(for: machine)
                        }
                    }, allowSelectMany: true)
                })
                .buttonStyle(PlainButtonStyle())
                .expended()
            }
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
        .onAppear {
            selection = NavigationItem(rawValue: sidebarSelection)
        }
        .onChange(of: selection) { newValue in
            sidebarSelection = newValue?.rawValue ?? ""
        }
        .navigationTitle("Rayon")
        .frame(minWidth: 200)
    }

    // copied from welcome view
    @State var openPickIdentity: Bool = false
    @State var pickedIdentity: RDIdentity.ID? = nil
    @State var pickedSemaphore: DispatchSemaphore? = nil

    func recentButton(for command: SSHCommandReader) -> some View {
        Button {
            UIBridge.requiresConfirmation(
                message: "Open connection with \(command.command)?"
            ) { confirmed in
                if confirmed {
                    store.beginTemporarySessionStartup(for: command, requestIdentityFromBackgroundThread: {
                        // TODO: FLAT THIS REQUEST
                        let sem = DispatchSemaphore(value: 0)
                        mainActor {
                            pickedSemaphore = sem
                            openPickIdentity = true
                        }
                        sem.wait()
                        return pickedIdentity
                    }, saveSessionOverrideControl: false) { sessionId in
                        RayonStore.shared.requestSessionInterface(session: sessionId)
                    }
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
        .sheet(isPresented: $openPickIdentity) {
            pickedSemaphore?.signal()
            pickedSemaphore = nil
        } content: {
            IdentityPickerSheetView { identity in
                pickedIdentity = identity
            }
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
                            store.beginSessionStartup(for: machine)
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
