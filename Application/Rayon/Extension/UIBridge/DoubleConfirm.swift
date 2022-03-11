//
//  DoubleConfirm.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import RayonModule
import SwiftUI

extension UIBridge {
    static func requiresConfirmation(message: String, confirmation: @escaping (Bool) -> Void) {
        if RayonStore.shared.disableConformation {
            confirmation(true)
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = message
        alert.addButton(withTitle: "Confirm")
        alert.addButton(withTitle: "Cancel")
        if let keyWindow = NSApplication.shared.keyWindow {
            alert.beginSheetModal(for: keyWindow) { resp in
                confirmation(resp == .alertFirstButtonReturn)
            }
        } else {
            let resp = alert.runModal()
            confirmation(resp == .alertFirstButtonReturn)
        }
    }
}
