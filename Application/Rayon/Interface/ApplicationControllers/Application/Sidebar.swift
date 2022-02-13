//
//  Sidebar.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/8.
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: RayonStore
    @SceneStorage("sidebar.selection") var sidebarSelection: String = ""
    @State var selection: NavigationItem? = nil

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
                    ServersView()
                } label: {
                    Label("Server", systemImage: "server.rack")
                }
                .badge(store.remoteMachines.count)
                .tag(NavigationItem.servers)
                NavigationLink {
                    IdentitiesView()
                } label: {
                    Label("Identity", systemImage: "key.fill")
                }
                .badge(store.userIdentities.count)
                .tag(NavigationItem.identities)
                NavigationLink {
                    SnippetsView()
                } label: {
                    Label("Snippet", systemImage: "arrow.right.doc.on.clipboard")
                }
                .badge(store.userSnippets.count)
                .tag(NavigationItem.snippets)
            }
            Section("Session") {
                if store.remoteSessions.count == 0 {
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
                    ForEach(store.remoteSessions) { session in
                        #if os(macOS)
                            Button {
                                store.requestSessionInterface(session: session.id)
                            } label: {
                                HStack {
                                    Label(session.context.remoteMachine.name, systemImage: "play.fill")
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
                                            store.destorySession(with: session.id)
                                        }
                                    }
                                } label: {
                                    Label("Close Connection", image: "trash")
                                }
                            }
                        #endif
                        #if os(iOS)

                        #endif
                    }
                    Button {
                        UIBridge.requiresConfirmation(
                            message: "Are you sure you want to stop all session?")
                        { confirmed in
                                guard confirmed else {
                                    return
                                }
                                for session in store.remoteSessions {
                                    store.destorySession(with: session.id)
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
                    ServerPickerView(onComplete: { machines in
                        for machine in machines {
                            store.beginSessionStartup(for: machine, autoOpen: false)
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
                    }, saveSessionOverrideControl: false, autoOpen: true)
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

    func recentButton(for machine: RDRemoteMachine.ID) -> some View {
        Group {
            if store.remoteMachines[machine].isNotPlaceholder() {
                Button {
                    UIBridge.requiresConfirmation(
                        message: "Open connection to \(store.remoteMachines[machine].name)?"
                    ) { confirmed in
                        if confirmed {
                            store.beginSessionStartup(for: machine)
                        }
                    }
                } label: {
                    HStack {
                        Label(store.remoteMachines[machine].name, systemImage: "rectangle.and.paperclip")
                        Spacer()
                    }
                    .background(Color.accentColor.opacity(0.0001))
                }
                .buttonStyle(PlainButtonStyle())
                .expended()
                .contextMenu {
                    Button {
                        for target in store.remoteMachines.machines where target.id == machine {
                            guard let id = target.associatedIdentity,
                                  let rid = UUID(uuidString: id)
                            else {
                                UIBridge.presentError(with: "Username for this record was not found")
                                return
                            }
                            let oid = store.userIdentities[rid]
                            guard oid.username.count > 0 else {
                                UIBridge.presentError(with: "Username for this record was not found")
                                return
                            }
                            UIBridge.sendPasteboard(str: "ssh \(oid.username)@\(target.remoteAddress) -p \(target.remotePort)")
                            return
                        }
                        UIBridge.presentError(with: "Data not found")
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
