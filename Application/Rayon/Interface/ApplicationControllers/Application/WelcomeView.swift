//
//  WelcomeView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import Colorful
import NSRemoteShell
import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var store: RayonStore

    @State var quickConnect: String = ""
    @FocusState var textFieldIsFocused: Bool
    @State var buttonDisabled: Bool = true
    @State var openPickIdentity: Bool = false
    @State var pickedIdentity: RDIdentity.ID? = nil
    @State var pickedSemaphore: DispatchSemaphore? = nil
    @State var suggestion: String? = nil

    @State var openThanksView: Bool = false

    var version: String {
        var ret = "Version: " +
            (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
            + " Build: " +
            (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
        #if DEBUG
            ret += " DEBUG"
        #endif
        return ret
    }

    var body: some View {
        VStack(spacing: 10) {
            Image("Avatar")
                .antialiased(true)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)

            Text("Quick Connect")
                .font(.system(.headline, design: .rounded))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    TextField("ssh root@www.example.com -p 22 ↵", text: $quickConnect)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($textFieldIsFocused)
                        .onChange(of: quickConnect, perform: { newValue in
                            if newValue.hasPrefix("ssh ssh ") {
                                // user pasting command
                                quickConnect.removeFirst("ssh ".count)
                            }
                            buttonDisabled = SSHCommandReader(command: newValue) == nil
                            refreshSuggestion()
                        })
                        .onChange(of: textFieldIsFocused, perform: { newValue in
                            // Autofill "ssh " if the text field is empty.
                            if newValue, quickConnect.isEmpty {
                                quickConnect = "ssh "
                            }
                        })
                        .onSubmit {
                            beginQuickConnect()
                        }
                        .padding(6)
                        .background(
                            Rectangle()
                                .opacity(0.1)
                                .cornerRadius(4)
                        )

                    Button {
                        beginQuickConnect()
                    } label: {
                        Circle()
                            .foregroundColor(.orange)
                            .overlay(
                                Image(systemName: "arrow.forward")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            )
                            .frame(width: 30, height: 30)
                    }
                    .disabled(buttonDisabled)
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(maxWidth: 400)

                if suggestion != nil {
                    suggestionButton
                        .transition(.offset(x: 0, y: 10).combined(with: .opacity))
                }
            }

            Toggle("Store Session", isOn: $store.saveTemporarySession)
        }
        .sheet(isPresented: $openPickIdentity) {
            pickedSemaphore?.signal()
            pickedSemaphore = nil
        } content: {
            IdentityPickerSheetView { identity in
                pickedIdentity = identity
            }
        }
        .sheet(isPresented: $openThanksView, onDismiss: nil) {
            ThanksView()
        }
        .navigationTitle("Rayon")
        .padding()
        .expended()
        .background(StarLinkView().ignoresSafeArea())
        .background(
            ColorfulView(
                colors: [Color.orange, Color.yellow],
                colorCount: 4
            )
            .ignoresSafeArea()
            .opacity(0.25)
        )
        .overlay(
            VStack {
                Spacer()
                Text(version)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .opacity(0.5)
            }
            .padding()
        )
        .requiresFrame()
        .toolbar {
            ToolbarItem {
                Button {
                    openThanksView.toggle()
                } label: {
                    Label("Learn More", systemImage: "questionmark")
                }
            }
        }
    }

    private var suggestionButton: some View {
        func fillSuggestion() {
            withAnimation(.spring()) {
                quickConnect = suggestion ?? quickConnect
            }
        }

        return Button(action: {
            fillSuggestion()
        }) {
            HStack {
                Text("Did you mean \"\(suggestion!)\"?")
                    .font(.system(size: 10))
                Text("⌘⏎")
                    .font(.system(size: 10))
                    .opacity(0.5)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .cornerRadius(4)
            )
        }
        .buttonStyle(BorderlessButtonStyle())
        .overlay(
            Button(action: {
                fillSuggestion()
            }) {
                Text("")
            }
            .offset(x: 0, y: 999_999)
            .keyboardShortcut(.return, modifiers: .command)
        )
    }

    private func beginQuickConnect() {
        guard let command = SSHCommandReader(command: quickConnect) else {
            // our error
            return
        }
        RayonStore
            .shared
            .beginTemporarySessionStartup(for: command) {
                // TODO: FLAT THIS REQUEST
                let sem = DispatchSemaphore(value: 0)
                mainActor {
                    pickedSemaphore = sem
                    openPickIdentity = true
                }
                sem.wait()
                return pickedIdentity
            }
    }

    private func refreshSuggestion() {
        let matchedCommands = store.recentRecord.lazy.map { connection -> String in
            connection.equivalentSSHCommand
        }.filter { command in
            command.hasPrefix(quickConnect) && command != quickConnect
        }

        withAnimation(.spring(response: 0.35)) {
            suggestion = quickConnect.count > 4 ? matchedCommands.first : nil
        }
    }
}
