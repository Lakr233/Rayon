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

    @State var openFilePicker: Bool = false
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
                PlaceholderView("Connection Closed", img: .connectionBroken)
            } else {
                VStack(spacing: 6) {
                    mainView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    bottomToolbar
                        .disabled(context.processConnection)
                        .disabled(context.isProgressRunning)
                    hintView
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
        .animation(.interactiveSpring(), value: context.currentFileList)
        .animation(.interactiveSpring(), value: context.currentHint)
        .animation(.interactiveSpring(), value: context.currentProgress)
        .animation(.interactiveSpring(), value: context.currentSpeed)
        .animation(.interactiveSpring(), value: context.currentProcessingFile)
//        .animation(.interactiveSpring(), value: context.currentProgressCancelable)
        .animation(.interactiveSpring(), value: context.processConnection)
        .navigationTitle("SFTP - " + context.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    var mainView: some View {
        Group {
            if context.isProgressRunning || context.processConnection {
                progressView
            } else if !context.connected {
                PlaceholderView("Connection Closed", img: .connectionBroken)
            } else {
                fileListView
            }
        }
    }

    var hintView: some View {
        Group {
            if !context.currentHint.isEmpty {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.accentColor)
                    Text(context.currentHint)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.accentColor)
                    Spacer()
                }
                .padding(6)
                .background(Color.gray.opacity(0.167)) // sh*t
                .cornerRadius(6)
            }
        }
    }

    var progressView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.5)
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
                makeFloatingButton("xmark") {
                    context.continueCurrentProgress = false
                }
                .foregroundColor(.red)
            }
        }
        .font(.system(.subheadline, design: .rounded))
        .frame(maxWidth: 400, maxHeight: .infinity)
    }

    var fileListView: some View {
        Group {
            if context.currentFileList.isEmpty {
                PlaceholderView("Nothing Available", img: .ghost)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        HStack {
                            Label("\(fileList.count) file(s) available", systemImage: "doc.on.doc")
                                .font(.system(.caption, design: .rounded))
                            Spacer()
                        }
                        Divider()
                        ForEach(fileList) { file in
                            RemoteFileElement(file: file, context: context)
                        }
                    }
                }
                .searchable(text: $searchKey)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var bottomToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                if !context.connected {
                    makeFloatingButton("arrow.counterclockwise") {
                        context.processBootstrap()
                    }
                }
                makeFloatingButton("trash") {
                    if context.connected {
                        context.processShutdown()
                    } else {
                        FileTransferManager.shared.end(for: context.id)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .foregroundColor(.red)
                Divider().frame(height: 20)
                makeFloatingButton("doc.viewfinder") {
                    UIBridge.openFileContainer()
                }
                makeFloatingButton("folder.badge.plus") {
                    UIBridge.askForInputText(
                        title: "New Folder",
                        message: "",
                        placeholder: "Folder Name",
                        payload: "",
                        canCancel: true
                    ) { name in
                        guard name.isValidAsFilename else {
                            UIBridge.presentError(with: "Invalid Filename")
                            return
                        }
                        context.createFolder(with: name)
                    }
                }
                .disabled(!context.connected)
                makeFloatingButton("arrow.up.doc") {
                    openFilePicker = true
                }
                .sheet(isPresented: $openFilePicker, onDismiss: nil) {
                    FilePickerUIRepresentable(types: [.item], allowMultiple: true) { urls in
                        debugPrint(urls)
                        context.upload(urls: urls)
                    }
                }
                .disabled(!context.connected)
                makeFloatingButton("arrow.clockwise") {
                    context.loadCurrentFileList()
                }
                .disabled(!context.connected)
                Divider().frame(height: 20)
                makeFloatingButton("arrow.right") {
                    UIBridge.askForInputText(
                        title: "Navigator",
                        message: "",
                        placeholder: "Remote Path",
                        payload: context.currentDir,
                        canCancel: true
                    ) { path in
                        guard !path.isEmpty, path.hasPrefix("/") else {
                            UIBridge.presentError(with: "Invalid Path")
                            return
                        }
                        context.navigate(path: path)
                    }
                }
                .disabled(!context.connected)
                pathItems
                    .disabled(!context.connected)
            }
        }
        .frame(maxWidth: .infinity)
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

    func makeFloatingButton(_ image: String, block: @escaping () -> Void) -> some View {
        Button {
            block()
        } label: {
            Image(systemName: image)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.bordered)
    }

    struct RemoteFileElement: View {
        let file: FileTransferContext.RemoteFile
        @StateObject var context: FileTransferContext

        var body: some View {
            Menu {
                if file.fstat.isDirectory {
                    Section {
                        Button {
                            let path = context.currentUrl.appendingPathComponent(file.name).path
                            context.navigate(path: path)
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
                        UIBridge.askForInputText(
                            title: "Rename",
                            message: "",
                            placeholder: "New File Name",
                            payload: file.name,
                            canCancel: true
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
                        let remoteUrl = context.currentUrl.appendingPathComponent(file.name)
                        let documentDir = FileManager
                            .default
                            .urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let base = documentDir
                        context.download(from: remoteUrl, toDir: base)
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
                content
            }
        }

        var content: some View {
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
                Image(systemName: "ellipsis")
                    .padding(.trailing)
            }
            .font(.system(.headline, design: .rounded))
            .padding(6)
            .background(Color.gray.opacity(0.167)) // sh*t
            .cornerRadius(6)
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
    }
}
