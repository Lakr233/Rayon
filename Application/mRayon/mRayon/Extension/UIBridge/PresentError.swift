//
//  PresentError.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import SPIndicator
import UIKit

extension UIBridge {
    static func presentSuccess(with message: String) {
        SPIndicator.present(
            title: message,
            message: "",
            preset: .done,
            haptic: .success,
            from: .top,
            completion: nil
        )
    }

    static func presentAlert(with message: String) {
        mainActor {
            let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Done", style: .default, handler: nil))
            UIWindow.shutUpKeyWindow?.topMostViewController?.present(alert, animated: true, completion: nil)
        }
    }

    static func presentError(with message: String, delay: Double = 0) {
        debugPrint("<InterfaceError> \(message)")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
//            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: "Done", style: .default, handler: nil))
//            UIWindow.shutUpKeyWindow?.topMostViewController?.present(alert, animated: true, completion: nil)
            #if DEBUG
                if message.count > 20 {
                    fatalError("message too long")
                }
            #endif
            SPIndicator.present(
                title: message,
                message: "",
                preset: .error,
                haptic: .error,
                from: .top,
                completion: nil
            )
        }
    }
}
