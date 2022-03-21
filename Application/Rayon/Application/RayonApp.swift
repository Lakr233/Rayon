//
//  RayonApp.swift
//  Shared
//
//  Created by Lakr Aream on 2022/2/8.
//

import AppKit
import CodeMirrorUI
import RayonModule
import SwiftUI
import XTerminalUI

@main
struct RayonApp: App {
    @StateObject private var store = RayonStore.shared

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        #if DEBUG
            NSLog(CommandLine.arguments.joined(separator: "\n"))
        #endif
        _ = RayonStore.shared
//        requiresMenubarSetup = MenubarTool.shared.requireMenubarSetup()

        NSLog("static main completed")
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

class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) static var shared: AppDelegate!

    override init() {
        super.init()
        debugPrint("\(self) \(#function)")
        assert(AppDelegate.shared == nil, "duplicated init of AppDelegate")
        AppDelegate.shared = self

        let timer = Timer(
            timeInterval: 1,
            target: self,
            selector: #selector(windowStatusWatcher),
            userInfo: nil,
            repeats: true
        )
        CFRunLoopAddTimer(CFRunLoopGetMain(), timer, .commonModes)
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        if !TerminalManager.shared.sessionContexts.isEmpty {
            UIBridge.requiresConfirmation(
                message: "One or more session is running, do you want to close them all?"
            ) { confirmed in
                guard confirmed else { return }
                TerminalManager.shared.closeAll()
                NSApp.terminate(nil)
            }
            return .terminateCancel
        }
        return .terminateNow
    }

    @objc
    func windowStatusWatcher() {
        let windows = NSApp.windows
            .filter { window in
                guard let readClass = NSClassFromString("NSStatusBarWindow") else {
                    return true
                }
                return !window.isKind(of: readClass.self)
            }
            .filter(\.isVisible)
        if windows.isEmpty, MenubarTool.shared.hasCat {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
    }
}
