//
//  RayonApp.swift
//  Shared
//
//  Created by Lakr Aream on 2022/2/8.
//

import SwiftUI

@main
struct RayonApp: App {
    @StateObject private var store = RayonStore.shared

    #if os(macOS)
        @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    init() {
        debugPrint("Welcome to Rayon~")
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(store)
        }
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            SidebarCommands()
        }
    }
}

#if os(macOS)
    class AppDelegate: NSObject, NSApplicationDelegate {
        func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
            if RayonStore.shared.remoteSessions.count > 0 {
                UIBridge.requiresConfirmation(
                    message: "One or more session is running, do you want to close them all?"
                ) { confirmed in
                    guard confirmed else { return }
                    for session in RayonStore.shared.remoteSessions {
                        RayonStore.shared.destorySession(with: session.id)
                    }
                    NSApp.terminate(nil)
                }
                return .terminateCancel
            }
            return .terminateNow
        }
    }
#endif
