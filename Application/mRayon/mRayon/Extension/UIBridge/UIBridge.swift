//
//  InterfaceBridge.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import UIKit

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
    static func sendPasteboard(str: String) {
        presentSuccess(with: "Pasteboard Sent")
        UIPasteboard.general.string = str
    }

    static func open(url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    static func askForInputText(
        title: String,
        message: String,
        placeholder: String,
        payload: String,
        canCancel: Bool,
        completion: @escaping (String) -> Void
    ) {
        let alert = UIAlertController(
            title: title.isEmpty ? nil : title,
            message: message.isEmpty ? nil : message,
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.text = payload
            textField.placeholder = placeholder
        }
        if canCancel {
            alert.addAction(.init(title: "Cancel", style: .cancel, handler: nil))
        }
        alert.addAction(.init(title: "OK", style: .default, handler: { [weak alert] _ in
            guard let str = alert?.textFields?.first?.text else {
                return
            }
            completion(str)
        }))
        UIWindow
            .shutUpKeyWindow?
            .topMostViewController?
            .present(alert, animated: true, completion: nil)
    }

    static func openFileContainer() {
        let str = "shareddocuments://" + FileManager
            .default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .path
        guard let url = URL(string: str) else {
            return
        }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            UIBridge.presentError(with: "File.app not installed")
        }
    }
}
