//
//  SidebarView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/2.
//

import RayonModule
import SwiftUI

extension SidebarView {
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
        .swipeActions {
            Button {
                delete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
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
                .swipeActions {
                    Button {
                        delete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
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
