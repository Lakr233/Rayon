//
//  CreateWindow.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/2/12.
//

import AppKit
import SwiftUI

class NSCloseProtectedWindow: NSWindow {
    var forceClose: Bool = false

    override func close() {
        guard !forceClose else {
            super.close()
            return
        }
        UIBridge.requiresConfirmation(
            message: "Are you sure you want to close this window?"
        ) { confirmed in
            guard confirmed else {
                return
            }
            super.close()
        }
    }
}

extension UIBridge {
    @discardableResult
    static func openNewWindow<T: View>(from view: T) -> Window {
        let hostView = NSHostingView(rootView: view)
        let window = NSCloseProtectedWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 400),
            styleMask: [
                .titled, .closable, .miniaturizable, .resizable, .fullSizeContentView,
            ],
            backing: .buffered,
            defer: false
        )
        window.animationBehavior = .alertPanel
        window.center()
        // Assign the toolbar to the window object
        let toolbar = NSToolbar(identifier: UUID().uuidString)
        window.toolbar = toolbar
        toolbar.insertItem(withItemIdentifier: .toggleSidebar, at: 0)
        window.toolbarStyle = .unifiedCompact
        window.titleVisibility = .visible
        window.contentView = hostView
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        return window
    }
}
