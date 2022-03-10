//
//  PresentError.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import Foundation

import AppKit

extension UIBridge {
    static func presentAlert(with message: String) {
        mainActor {
            let alert = NSAlert()
            alert.messageText = message
            if let keyWindow = NSApplication.shared.keyWindow {
                alert.beginSheetModal(for: keyWindow, completionHandler: nil)
            } else {
                alert.runModal()
            }
        }
    }

    static func presentError(with message: String, delay: Double = 0) {
        debugPrint("<InterfaceError> \(message)")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = message
            if let keyWindow = NSApplication.shared.keyWindow {
                alert.beginSheetModal(for: keyWindow, completionHandler: nil)
            } else {
                alert.runModal()
            }
        }
    }
}
