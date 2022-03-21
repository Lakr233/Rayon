//
//  TerminalView.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/3/10.
//

import RayonModule
import SwiftUI
import XTerminalUI

struct TerminalView: View {
    @StateObject var context: TerminalManager.Context

    @StateObject var store = RayonStore.shared
    @State var interfaceToken = UUID()

    var body: some View {
        Group {
            if context.interfaceToken == interfaceToken {
                context.termInterface
                    .padding(4)
                    .onChange(of: store.terminalFontSize) { newValue in
                        context.termInterface.setTerminalFontSize(with: newValue)
                    }
                    .onAppear {
                        context.termInterface.setTerminalFontSize(with: store.terminalFontSize)
                    }
            } else {
                Text("Terminal Transfer To Another Window")
            }
        }
        .onAppear {
            debugPrint("set interface token \(interfaceToken)")
            context.interfaceToken = interfaceToken
        }
        .toolbar {
            ToolbarItem {
                Button {
                    store.terminalFontSize -= 1
                } label: {
                    Label("Decrease Font Size", systemImage: "text.badge.minus")
                }
                .disabled(store.terminalFontSize <= 4)
            }
            ToolbarItem {
                Button {
                    RayonStore.shared.terminalFontSize += 1
                } label: {
                    Label("Increase Font Size", systemImage: "text.badge.plus")
                }
                .disabled(store.terminalFontSize >= 30)
            }
            ToolbarItem { // divider
                Button {} label: { HStack { Divider().frame(height: 15) } }
                    .disabled(true)
            }
            ToolbarItem {
                Button {
                    if context.closed {
                        DispatchQueue.global().async {
                            self.context.putInformation("[i] Reconnect will use the information you provide previously,")
                            self.context.putInformation("    if the machine was edited, create a new terminal.")
                            self.context.processBootstrap()
                        }
                    } else {
                        UIBridge.requiresConfirmation(
                            message: "Are you sure you want to close the terminal?"
                        ) { y in
                            if y { context.processShutdown() }
                        }
                    }
                } label: {
                    if context.closed {
                        Label("Reconnect", systemImage: "arrow.counterclockwise")
                    } else {
                        Label("Close", systemImage: "xmark")
                    }
                }
            }
        }
        .navigationTitle(context.navigationTitle)
        .navigationSubtitle(context.navigationSubtitle)
    }

    func safeWriteBase64(_ base64: String) {
        guard let data = Data(base64Encoded: base64),
              let str = String(data: data, encoding: .utf8)
        else {
            debugPrint("failed to decode \(base64)")
            return
        }
        safeWrite(str)
    }

    func safeWrite(_ str: String) {
        guard !context.closed else {
            return
        }
        guard context.interfaceToken == interfaceToken else {
            return
        }
        context.insertBuffer(str)
    }

    func makeKeyboardFloatingButton(_ image: String, block: @escaping () -> Void) -> some View {
        Button {
            guard !context.closed else { return }
            block()
        } label: {
            Image(systemName: image)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.bordered)
        .animation(.spring(), value: context.interfaceDisabled)
        .disabled(context.interfaceDisabled)
    }
}
