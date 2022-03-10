//
//  WelcomeView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/2.
//

import Colorful
import RayonModule
import SwiftUI

@available(iOS 15.0, *)
struct WelcomeViewModifier15: ViewModifier {
    let parent: WelcomeView
    @FocusState var textFieldIsFocused: Bool

    func body(content: Content) -> some View {
        content
            .onSubmit {
                parent.beginQuickConnect()
            }
            .focused($textFieldIsFocused)
            .onChange(of: textFieldIsFocused, perform: { newValue in
                // Autofill "ssh " if the text field is empty.
                if newValue, parent.quickConnect.isEmpty {
                    parent.quickConnect = "ssh "
                }
            })
    }

    init(parent: WelcomeView) {
        self.parent = parent
    }
}

struct WelcomeView: View {
    @EnvironmentObject var store: RayonStore

    @State public var quickConnect: String = ""

    @State var buttonDisabled: Bool = true
    @State var suggestion: String? = nil

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
        VStack(alignment: .center, spacing: 10) {
            Image("Avatar")
                .antialiased(true)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if #available(iOS 15.0, *) {
                        TextField("ssh root@www.example.com -p 22 ↵", text: $quickConnect)
                            .modifier(WelcomeViewModifier15(parent: self))
                    } else {
                        TextField("ssh root@www.example.com -p 22 ↵", text: $quickConnect, onCommit: beginQuickConnect)
                    }
                }
                .textFieldStyle(PlainTextFieldStyle())
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.system(.headline, design: .rounded))
                .onChange(of: quickConnect, perform: { newValue in
                    if newValue.hasPrefix("ssh ssh ") {
                        // user pasting command
                        quickConnect.removeFirst("ssh ".count)
                    }
                    buttonDisabled = SSHCommandReader(command: newValue) == nil
                    refreshSuggestion()
                })
                .padding(6)
                .background(
                    Rectangle()
                        .foregroundColor(.black.opacity(0.1))
                        .cornerRadius(4)
                )
                .frame(maxWidth: 400)

                if suggestion != nil {
                    suggestionButton
                        .transition(.offset(x: 0, y: 10).combined(with: .opacity))
                }
            }

            Button {
                beginQuickConnect()
            } label: {
                Circle()
                    .foregroundColor(.accentColor)
                    .overlay(
                        Image(systemName: "arrow.forward")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    )
                    .frame(width: 45, height: 45)
            }
            .disabled(buttonDisabled)
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 10)
            Spacer()
                .frame(height: 40)
        }
        .navigationTitle("Connect")
        .padding()
        .expended()
        .background(StarLinkView().ignoresSafeArea())
        .overlay(
            VStack {
                Spacer()
                Text(version)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .opacity(0.5)
                Spacer()
                    .frame(height: 20)
            }
        )
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
                    .foregroundColor(.white)
                    .font(.system(.headline, design: .rounded))
            }
            .padding(6)
            .background(
                Rectangle()
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)
            )
        }
        .buttonStyle(BorderlessButtonStyle())
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

    public func beginQuickConnect() {
        guard let command = SSHCommandReader(command: quickConnect) else {
            return
        }
        TerminalManager.shared.begin(for: command)
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        createPreview {
            AnyView(WelcomeView())
        }
    }
}
