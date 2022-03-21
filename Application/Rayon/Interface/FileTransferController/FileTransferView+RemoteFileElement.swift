//
//  FileTransferView+RemoteFileElement.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/3/21.
//

import SwiftUI

extension FileTransferView {
    struct RemoteFileElement: View {
        let file: FileTransferContext.RemoteFile
        @StateObject var context: FileTransferContext

        var body: some View {
            HStack {
                Image(systemName: sfAvatar)
                    .frame(width: 25)
                VStack(alignment: .leading, spacing: 6) {
                    Text(file.name)
                        .font(.system(.headline, design: .rounded))
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(
                            file.fstat.permissionDescription +
                                " size: " + size +
                                " uid: \(file.fstat.ownerUID)" +
                                " gid: \(file.fstat.ownerGID)"
                        )
                        .font(.system(.caption, design: .monospaced))
                        .opacity(0.5)
                    }
                }
                Spacer()
                buttonGroup
                    .frame(width: 50)
                    .padding(.trailing)
            }
            .font(.system(.headline, design: .rounded))
            .padding(6)
            .background(Color.gray.opacity(0.167)) // sh*t
            .cornerRadius(6)
            .makeHoverPointer()
            .onTapGesture(count: 2) {
                debugPrint("double tap")
                if file.fstat.isDirectory {
                    openDir()
                } else {
                    runDownload()
                }
            }
        }

        var buttonGroup: some View {
            Menu {
                Section {
                    if file.fstat.isDirectory {
                        Button {
                            openDir()
                        } label: {
                            Label("Open", systemImage: "arrow.right")
                        }
                    }
                }
                Section {
                    Button {
                        UIBridge.sendPasteboard(str: file.name)
                    } label: {
                        Label("Copy Name", systemImage: "")
                    }
                    Button {
                        let path = context.currentUrl.appendingPathComponent(file.name).path
                        UIBridge.sendPasteboard(str: path)
                    } label: {
                        Label("Copy Path", systemImage: "")
                    }
                }
                Section {
                    Button {
                        UIBridge.askForInput(
                            title: "Rename File",
                            message: "",
                            defaultValue: file.name
                        ) { newValue in
                            guard newValue.isValidAsFilename else {
                                UIBridge.presentError(with: "Invalid Filename")
                                return
                            }
                            let base = context.currentUrl
                            context.rename(
                                from: base.appendingPathComponent(file.name),
                                to: base.appendingPathComponent(newValue)
                            )
                        }
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                }
                Section {
                    Button {
                        runDownload()
                    } label: {
                        Label("Download", systemImage: "arrow.down")
                    }
                }
                Section {
                    Button {
                        let item = context.currentUrl.appendingPathComponent(file.name)
                        UIBridge.requiresConfirmation(
                            message: "Are you sure you want to delete \(item.path)?"
                        ) { y in
                            if y { context.delete(item: item) }
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }

        var sfAvatar: String {
            if file.fstat.isDirectory {
                return "folder"
            }
            if file.fstat.isLink {
                return "link"
            }
            return "doc.text"
        }

        var size: String {
            ByteCountFormatter().string(fromByteCount: Int64(truncating: file.fstat.size ?? 0))
        }

        func openDir() {
            let path = context.currentUrl.appendingPathComponent(file.name).path
            context.navigate(path: path)
        }

        func runDownload() {
            let remoteUrl = context.currentUrl.appendingPathComponent(file.name)
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = true
            if let window = NSApplication.shared.keyWindow {
                panel.beginSheetModal(for: window) { resp in
                    if resp == .OK, let url = panel.url {
                        context.download(from: remoteUrl, toDir: url)
                    }
                }
            }
        }
    }
}
