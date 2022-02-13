//
//  DoubleConfirm.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import SwiftUI

extension UIBridge {
    static func requiresConfirmation(message: String, confirmation: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: "Confirm?", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            confirmation(false)
        }))
        alert.addAction(UIAlertAction(title: "Confirm", style: .destructive, handler: { _ in
            confirmation(true)
        }))
        UIWindow.shutUpKeyWindow?.topMostViewController?.present(alert, animated: true, completion: nil)
    }
}
