//
//  TerminalView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/2.
//

import RayonModule
import SwiftUI
import XTerminalUI

struct TerminalView: View {
    @StateObject var context: TerminalContext

    @State var interfaceToken = UUID()

    @State var terminalSize: CGSize = TerminalContext.defaultTerminalSize

    @State var openControlKeyPopover: Bool = false
    @State var controlKey: String = ""

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        Group {
            if context.interfaceToken == interfaceToken {
                GeometryReader { r in
                    VStack {
                        context.termInterface
                            .onChange(of: r.size) { _ in
                                guard context.interfaceToken == interfaceToken else {
                                    debugPrint("interface token mismatch")
                                    return
                                }
                                updateTerminalSize()
                            }
                            .padding(r.size.width > 600 ? 8 : 2)
                        if !context.destroyedSession {
                            buttonGroup
                        }
                    }
                }
            } else {
                PlaceholderView("Terminal Transfer To Another Window", img: .emptyWindow)
            }
        }
        .disabled(context.destroyedSession)
        .onAppear {
            debugPrint("set interface token \(interfaceToken)")
            context.interfaceToken = interfaceToken
        }
        .navigationTitle(context.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    var buttonGroup: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 5) {
                Group {
                    if context.closed {
                        makeKeyboardFloatingButton("arrow.counterclockwise", disableWhenClosed: false) {
                            DispatchQueue.global().async {
                                context.putInformation("[i] Reconnect will use the information you provide previously,")
                                context.putInformation("    if the machine was edited, create a new terminal.")
                                context.processBootstrap()
                            }
                        }
                    }
                    makeKeyboardFloatingButton("trash", disableWhenClosed: false) {
                        if context.closed {
                            presentationMode.wrappedValue.dismiss()
                            TerminalManager.shared.end(for: context.id)
                        } else {
                            UIBridge.requiresConfirmation(
                                message: "Are you sure you want to close this session?"
                            ) { yes in
                                if yes { context.processShutdown() }
                            }
                        }
                    }
                    .foregroundColor(.red)
                    makeKeyboardFloatingButton("doc.on.clipboard") {
                        guard let str = UIPasteboard.general.string else {
                            UIBridge.presentError(with: "Empty Pasteboard")
                            return
                        }
                        UIBridge.requiresConfirmation(
                            message: "Are you sure you want to paste following string?\n\n\(str)"
                        ) { yes in
                            if yes { self.safeWrite(str) }
                        }
                    }
                }
                Divider().frame(height: 20)
                Group {
                    makeKeyboardFloatingButton("arrow.right.to.line.compact") {
                        safeWriteBase64("CQ==")
                    }
                    makeKeyboardFloatingButton("control") {
                        openControlKeyPopover = true
                    }
                    .popover(isPresented: $openControlKeyPopover) {
                        HStack(spacing: 2) {
                            Text("Ctrl + ")
                            TextField("Key To Send", text: $controlKey)
                                .disableAutocorrection(true)
                                .onChange(of: controlKey) { newValue in
                                    guard let f = newValue.uppercased().last else {
                                        if !controlKey.isEmpty { controlKey = "" }
                                        return
                                    }
                                    if controlKey != String(f) {
                                        controlKey = String(f)
                                    }
                                }
                                .onSubmit {
                                    sendCtrl()
                                }
                            Button {
                                sendCtrl()
                            } label: {
                                Image(systemName: "return")
                            }
                        }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .padding()
                        .frame(width: 200, height: 40)
                    }
                    makeKeyboardFloatingButton("escape") {
                        safeWriteBase64("Gw==")
                    }
                }
                Divider().frame(height: 20)
                Group {
                    makeKeyboardFloatingButton("arrow.left.circle.fill") {
                        safeWriteBase64("G1tE")
                    }
                    makeKeyboardFloatingButton("arrow.right.circle.fill") {
                        safeWriteBase64("G1tD")
                    }
                    makeKeyboardFloatingButton("arrow.up.circle.fill") {
                        safeWriteBase64("G1tB")
                    }
                    makeKeyboardFloatingButton("arrow.down.circle.fill") {
                        safeWriteBase64("G1tC")
                    }
                }
            }
            .padding()
        }
    }

    func sendCtrl() {
        let key = controlKey
        controlKey = ""
        openControlKeyPopover = false
        /*
         Note: The Ctrl-Key representation is simply associating the non-printable characters from ASCII code 1 with the printable (letter) characters from ASCII code 65 ("A"). ASCII code 1 would be ^A (Ctrl-A), while ASCII code 7 (BEL) would be ^G (Ctrl-G). This is a common representation (and input method) and historically comes from one of the VT series of terminals.

         https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
         */
        guard key.count == 1 else { return }
        let char = Character(key)
        guard let asciiValue = char.asciiValue,
              let asciiInt = Int(exactly: asciiValue) // 65 = "A" 1 = "CTRL+A"
        else {
            debugPrint("failed to encode control")
            return
        }
        let ctrlInt = asciiInt - 64
        guard ctrlInt > 0, ctrlInt < 65 else {
            debugPrint("control character overflow")
            return
        }
        guard let us = UnicodeScalar(ctrlInt) else {
            debugPrint("failed to encode control")
            return
        }
        let nc = Character(us)
        let st = String(nc)
        safeWrite(st)
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

    func makeKeyboardFloatingButton(_ image: String, disableWhenClosed: Bool = true, block: @escaping () -> Void) -> some View {
        Button {
            if context.closed, disableWhenClosed { return }
            block()
        } label: {
            Image(systemName: image)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.bordered)
        .animation(.spring(), value: context.interfaceDisabled)
        .disabled(disableWhenClosed && context.interfaceDisabled)
    }

    func updateTerminalSize() {
        let core = context.termInterface
        let origSize = terminalSize
        DispatchQueue.global().async {
            let newSize = core.requestTerminalSize()
            guard newSize.width > 5, newSize.height > 5 else {
                debugPrint("ignoring malformed terminal size: \(newSize)")
                return
            }
            if newSize != origSize {
                mainActor {
                    guard context.interfaceToken == interfaceToken else {
                        debugPrint("interface token mismatch")
                        return
                    }
                    debugPrint("new terminal size: \(newSize)")
                    terminalSize = newSize
                    context.shell.explicitRequestStatusPickup()
                }
            }
        }
    }
}
