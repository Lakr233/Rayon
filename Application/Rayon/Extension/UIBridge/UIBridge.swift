//
//  InterfaceBridge.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import Foundation

import AppKit

/// Not actually a Actor but I like it
/// - Parameter run: the job to be fired on main thread
func mainActor(delay: Double = 0, run: @escaping () -> Void) {
    guard delay == 0, Thread.isMainThread else {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            run()
        }
        return
    }
    run()
}

enum UIBridge {
    static let itemSpacing: Double = 10

    static func sendPasteboard(str: String) {
        debugPrint("\(#function) \(str)")

        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(str, forType: .string)
    }

    static func open(url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)),
            with: nil
        )
    }

    static func askForInput(title: String, message: String, defaultValue: String, complete: @escaping (String) -> Void) {
        let msg = NSAlert()
        msg.addButton(withTitle: "OK") // 1st button
        msg.addButton(withTitle: "Cancel") // 2nd button
        msg.messageText = title
        msg.informativeText = message

        let txt = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        txt.stringValue = defaultValue
        msg.window.initialFirstResponder = txt

        msg.accessoryView = txt

        msg.beginSheetModal(for: NSApp.keyWindow ?? NSWindow()) { resp in
            if resp == .alertFirstButtonReturn {
                complete(txt.stringValue)
            }
        }
    }
}
