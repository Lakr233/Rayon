//
//  MainSessionSidebar.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/11.
//

import SwiftUI

private struct _TerminalTitleView: View {
    @StateObject var info: RDSessionAssoicatedContext.TerminalSessionInfo

    var body: some View {
        Label(info.title.count > 0 ? info.title : "Untitled Terminal",
              systemImage: TerminalManager
                  .shared
                  .terminalSession(for: info.id)
                  .completed ? "xmark.square.fill" : "terminal.fill")
    }
}

struct SessionSidebarView: View {
    @EnvironmentObject var context: RDSessionAssoicatedContext

    @State var openProgressSheet: Bool = false
    @State var selection: UUID? = nil

    var body: some View {
        List(selection: $selection) {
            Section("Information") {
                NavigationLink {
                    SessionInfoView()
                } label: {
                    Label("Session Info", systemImage: "info.circle")
                }
                Button {
                    closeConnection()
                } label: {
                    HStack {
                        Label("Close Session", systemImage: "trash")
                        Spacer()
                    }
                    .background(Color.accentColor.opacity(0.0001))
                }
                .buttonStyle(PlainButtonStyle())
                .expended()
            }
            Section("Terminals") {
                ForEach(context.terminalSessions, id: \.self) { id in
                    NavigationLink {
                        SessionTerminalView(token: id)
                    } label: {
                        _TerminalTitleView(info: context.terminalSessionInfos[id] ?? .init())
                    }
                    .tag(id)
                    .contextMenu {
                        Button {
                            func closeChannel() {
                                context.terminateTermSession(for: id)
                            }
                            if context.terminalChannelAlive(for: id) {
                                UIBridge.requiresConfirmation(
                                    message: "Attempt to close a running channel"
                                ) { confirmed in
                                    if confirmed { closeChannel() }
                                }
                            } else { closeChannel() }
                        } label: {
                            Label("Close Tab", image: "trash")
                        }
                    }
                }
                Button {
                    createTermianlSession()
                } label: {
                    HStack {
                        Label("New Channel", systemImage: "plus.viewfinder")
                        Spacer()
                    }
                    .background(Color.accentColor.opacity(0.0001))
                }
                .buttonStyle(PlainButtonStyle())
                .expended()
            }
            Spacer()
            Spacer()
            Spacer()
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
        .expended()
        .sheet(isPresented: $openProgressSheet, onDismiss: nil) {
            SheetTemplate.makeProgress(text: "Operation in progress")
        }
    }

    func createTermianlSession() {
        context.createSession()
    }

    func closeConnection() {
        UIBridge.requiresConfirmation(
            message: "This will close all sub-channel associated to this session"
        ) { confirmed in
            if confirmed {
                RayonStore.shared.destorySession(with: context.sessionID)
            }
        }
    }
}
