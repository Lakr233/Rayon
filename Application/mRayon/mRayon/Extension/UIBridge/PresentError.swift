//
//  PresentError.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import Foundation

import UIKit

extension UIBridge {
    static func presentAlert(with message: String) {
        mainActor {
            let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Done", style: .default, handler: nil))
            UIWindow.shutUpKeyWindow?.topMostViewController?.present(alert, animated: true, completion: nil)
        }
    }

    static func presentError(with message: String, delay: Double = 0.5) {
        debugPrint("<InterfaceError> \(message)")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Done", style: .default, handler: nil))
            UIWindow.shutUpKeyWindow?.topMostViewController?.present(alert, animated: true, completion: nil)
        }
    }
}
