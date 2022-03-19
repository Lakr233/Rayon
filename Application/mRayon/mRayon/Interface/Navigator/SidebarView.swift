//
//  SidebarView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/2.
//

import RayonModule
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: RayonStore

    @StateObject var monitorManager = MonitorManager.shared
    @StateObject var terminalManager = TerminalManager.shared
    @StateObject var forwardBackend = PortForwardBackend.shared
    @StateObject var transferBackend = FileTransferManager.shared

    var body: some View {
        NavigationView {
            sidebar
            JustWelcomeView()
        }
    }

    var sidebar: some View {
        List {
            app
            monitor
            terminals
            transfers
//            portForward
            if store.storeRecent { recent }
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
                PortForwardView()
            } label: {
                Label("Port Forward", systemImage: "arrow.left.arrow.right")
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
                    .swipeActions {
                        Button {
                            monitorManager.end(for: context.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
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
                        Label(context.navigationTitle, systemImage: "terminal")
                    }
                    .swipeActions {
                        Button {
                            terminalManager.end(for: context.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
        }
    }

    var transfers: some View {
        Section("File Transfer") {
            if transferBackend.transfers.isEmpty {
                Button {} label: {
                    HStack {
                        Label("No Session", systemImage: "square.dashed")
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .expended()
            } else {
                ForEach(transferBackend.transfers) { context in
                    NavigationLink {
                        FileTransferView(context: context)
                    } label: {
                        Label(context.navigationTitle, systemImage: "externaldrive.connected.to.line.below")
                    }
                    .swipeActions {
                        Button {
                            transferBackend.end(for: context.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
        }
    }

//    var portForward: some View {
//        Section("Port Forward") {
//            if forwardBackend.container.isEmpty {
//                Button {} label: {
//                    HStack {
//                        Label("No Session", systemImage: "square.dashed")
//                        Spacer()
//                    }
//                }
//                .buttonStyle(PlainButtonStyle())
//                .expended()
//            } else {
//                ForEach(forwardBackend.container) { context in
//                    NavigationLink {
//                        PortForwardExecView(context: context)
//                    } label: {
//                        Label(
//                            context.info.shortDescription(),
//                            systemImage: context.info.forwardOrientation == .listenLocal ? "l.joystick.tilt.right" : "r.joystick.tilt.right"
//                        )
//                    }
//                    .swipeActions {
//                        Button {
//                            forwardBackend.endSession(withPortForwardID: context.info.id)
//                        } label: {
//                            Label("Delete", systemImage: "trash")
//                        }
//                        .tint(.red)
//                    }
//                }
//            }
//        }
//    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView()
            .previewDevice(PreviewDevice(rawValue: "iPad mini (6th generation)"))
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
