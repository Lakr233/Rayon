//
//  InterfaceBridge.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import Foundation

#if os(iOS)
    import UIKit
#endif

#if os(macOS)
    import AppKit
#endif

class UIBridge {
    static let itemSpacing: Double = 10

    static func sendPasteboard(str: String) {
        debugPrint("\(#function) \(str)")
        #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(str, forType: .string)
        #endif
        #if os(iOS)
            UIPasteboard.general.string = str
        #endif
    }

    static func open(url: URL) {
        #if os(macOS)
            NSWorkspace.shared.open(url)
        #endif
        #if os(iOS)
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        #endif
    }

    static func toggleSidebar() {
        #if os(macOS)
            NSApp.keyWindow?.firstResponder?.tryToPerform(
                #selector(NSSplitViewController.toggleSidebar(_:)),
                with: nil
            )
        #endif
    }
}
