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
        debugPrint("\(#function) \(str)")
        UIPasteboard.general.string = str
    }

    static func open(url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
