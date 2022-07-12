//
//  mRayonApp.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/2.
//

import CodeEditorUI
import RayonModule
import SwiftUI
import XTerminalUI

@main
struct mRayonApp: App {
    @StateObject private var store = RayonStore.shared

    init() {
        #if DEBUG
            NSLog("\nCommand Arguments:\n" + CommandLine.arguments.joined(separator: "\n"))
        #endif

        _ = LogRedirect.shared
        _ = RayonStore.shared

        NSLog("static main completed")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    // optimize later on flight exp
                    let editor = SCodeEditor()
                    let xterm = STerminalView()
                    checkAgreement()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        withExtendedLifetime(editor) {
                            debugPrint("editor \(editor) prewarm done")
                        }
                        withExtendedLifetime(xterm) {
                            debugPrint("xterm \(xterm) prewarm done")
                        }
                    }
                }
                .onChange(of: store.licenseAgreed) { _ in
                    checkAgreement()
                }
        }
    }

    func checkAgreement() {
        guard !store.licenseAgreed else {
            return
        }
        let host = UIHostingController(rootView: AgreementView())
        host.preferredContentSize = preferredPopOverSize
        host.isModalInPresentation = true
        host.modalTransitionStyle = .coverVertical
        host.modalPresentationStyle = .formSheet
        mainActor(delay: 0.5) {
            UIWindow.shutUpKeyWindow?
                .topMostViewController?
                .present(next: host)
        }
    }
}
