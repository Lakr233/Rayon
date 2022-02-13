//
//  PresentError.swift
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

extension UIBridge {
    static func presentAlert(with message: String) {
        mainActor {
            #if os(iOS)
                let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Done", style: .default, handler: nil))
                UIApplication.shared.keyWindow?.topMostViewController?.present(alert, animated: true, completion: nil)
            #else
                let alert = NSAlert()
                alert.messageText = message
                if let keyWindow = NSApplication.shared.keyWindow {
                    alert.beginSheetModal(for: keyWindow, completionHandler: nil)
                } else {
                    alert.runModal()
                }
            #endif
        }
    }

    static func presentError(with message: String, delay: Double = 0.5) {
        debugPrint("<InterfaceError> \(message)")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            #if os(iOS)
                let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Done", style: .default, handler: nil))
                UIApplication.shared.keyWindow?.topMostViewController?.present(alert, animated: true, completion: nil)
            #else
                let alert = NSAlert()
                alert.alertStyle = .critical
                alert.messageText = message
                if let keyWindow = NSApplication.shared.keyWindow {
                    alert.beginSheetModal(for: keyWindow, completionHandler: nil)
                } else {
                    alert.runModal()
                }
            #endif
        }
    }
}
