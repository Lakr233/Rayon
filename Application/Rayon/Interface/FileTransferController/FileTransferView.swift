//
//  FileTransferView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/18.
//

import SwiftUI

struct FileTransferView: View {
    @StateObject var context: FileTransferContext
    @Environment(\.presentationMode) var presentationMode

    @State var searchKey: String = ""

    var fileList: [FileTransferContext.RemoteFile] {
        if searchKey.isEmpty {
            return context.currentFileList
        }
        let key = searchKey.lowercased()
        return context.currentFileList
            .filter { file in
                if file.name.lowercased().contains(key) {
                    return true
                }
                return false
            }
    }

    var body: some View {
        Group {
            if context.destroyedSession {
                Text("Connection Closed")
                    .font(.system(.headline, design: .rounded))
            } else {
                mainView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .animation(.interactiveSpring(), value: context.currentFileList)
        .animation(.interactiveSpring(), value: context.currentProgress)
        .animation(.interactiveSpring(), value: context.currentSpeed)
        .animation(.interactiveSpring(), value: context.currentProcessingFile)
        .animation(.interactiveSpring(), value: context.processConnection)
        .navigationTitle(context.machine.name + ":" + context.navigationSubtitle)
        .navigationSubtitle("\(fileList.count) items - \(context.currentHint)")
    }

    var mainView: some View {
        Group {
            if context.isProgressRunning || context.processConnection {
                progressView
            } else if !context.connected {
                Text("Connection Closed")
            } else {
                fileListView
            }
        }
        .searchable(text: $searchKey)
        .toolbar {
            ToolbarItem {
                if !context.connected {
                    Button {
                        context.processBootstrap()
                    } label: {
                        Label("Reconnect", systemImage: "cable.connector.horizontal")
                    }
                    .disabled(context.processConnection)
                    .disabled(context.isProgressRunning)
                }
            }
            ToolbarItem {
                Button {
                    if context.connected {
                        context.processShutdown()
                    } else {
                        FileTransferManager.shared.end(for: context.id)
                    }
                } label: {
                    Label("Close", systemImage: "xmark")
                }
                .disabled(context.processConnection)
                .disabled(context.isProgressRunning)
            }
            ToolbarItem {
                if context.connected {
                    Button {
                        UIBridge.askForInput(
                            title: "Navigate",
                            message: "",
                            defaultValue: context.currentDir
                        ) { str in
                            context.currentDir = str
                            context.loadCurrentFileList()
                        }
                    } label: {
                        Label("Navigate", systemImage: "arrow.turn.down.right")
                    }
                    .disabled(context.processConnection)
                    .disabled(context.isProgressRunning)
                }
            }
            ToolbarItem {
                if context.connected {
                    Button {
                        UIBridge.askForInput(
                            title: "New Folder",
                            message: "",
                            defaultValue: ""
                        ) { newValue in
                            debugPrint(newValue)
                            guard newValue.isValidAsFilename else {
                                UIBridge.presentError(with: "Invalid Filename")
                                return
                            }
                            context.createFolder(with: newValue)
                        }
                    } label: {
                        Label("Create Folder", systemImage: "folder.badge.plus")
                    }
                    .disabled(context.processConnection)
                    .disabled(context.isProgressRunning)
                }
            }
            ToolbarItem {
                if context.connected {
                    Button {
                        let file = NSOpenPanel()
                        file.canChooseDirectories = true
                        file.canChooseFiles = true
                        file.allowsMultipleSelection = true
                        file.beginSheetModal(for: NSApp.keyWindow ?? NSWindow()) { resp in
                            if resp == .OK {
                                let urls = file.urls
                                context.upload(urls: urls)
                            }
                        }
                    } label: {
                        Label("Upload", systemImage: "arrow.up.doc")
                    }
                    .disabled(context.processConnection)
                    .disabled(context.isProgressRunning)
                }
            }
            ToolbarItem {
                if context.currentUrl.pathComponents.count > 1 {
                    Button {
                        context.currentDir = context
                            .currentUrl
                            .deletingLastPathComponent()
                            .path
                        context.loadCurrentFileList()
                    } label: {
                        Label("Go Up Folder", systemImage: "arrowshape.turn.up.left")
                    }
                    .disabled(context.processConnection)
                    .disabled(context.isProgressRunning)
                }
            }
            ToolbarItem {
                if context.connected {
                    Button {
                        context.loadCurrentFileList()
                    } label: {
                        Label("Reload", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(context.processConnection)
                    .disabled(context.isProgressRunning)
                }
            }
        }
    }

    var progressView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .padding()
            if context.totalProgress.totalUnitCount > 0 {
                ProgressView(context.totalProgress)
                    .progressViewStyle(.linear)
            }
            if context.currentProgress.totalUnitCount > 0 {
                ProgressView(context.currentProgress)
                    .progressViewStyle(.linear)
            }
            if !context.currentProcessingFile.isEmpty {
                if context.currentSpeed > 0 {
                    HStack {
                        Text(URL(fileURLWithPath: context.currentProcessingFile).lastPathComponent)
                        Spacer()
                        Text(ByteCountFormatter().string(fromByteCount: Int64(context.currentSpeed)))
                            .monospacedDigit()
                    }
                } else {
                    // usually delete
                    Text(URL(fileURLWithPath: context.currentProcessingFile).path)
                }
            }
            if context.currentProgressCancelable, context.continueCurrentProgress {
                Button {
                    context.continueCurrentProgress = false
                } label: {
                    Text("Cancel")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .font(.system(.subheadline, design: .rounded))
        .frame(maxWidth: 400, maxHeight: .infinity)
    }

    var fileListView: some View {
        Group {
            if context.currentFileList.isEmpty {
                Text("Nothing Available")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(fileList) { file in
                            RemoteFileElement(file: file, context: context)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var pathItems: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< context.currentUrl.pathComponents.count, id: \.self) { idx in
                Button {
                    rollToPath(with: idx)
                } label: {
                    Text(context.currentUrl.pathComponents[idx])
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .frame(height: 20)
                }
                .buttonStyle(.bordered)
                if idx != context.currentUrl.pathComponents.count - 1 {
                    Image(systemName: "arrowtriangle.forward.fill")
                        .font(.system(size: 6, weight: .semibold, design: .rounded))
                        .foregroundColor(.accentColor)
                }
            }
        }
    }

    func rollToPath(with index: Int) {
        var url = context.currentUrl
        let cnt = index + 1
        while url.pathComponents.count > cnt, !url.pathComponents.isEmpty {
            url.deleteLastPathComponent()
        }
        debugPrint(url.path)
        context.currentDir = url.path
        context.loadCurrentFileList()
    }
}
