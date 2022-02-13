//
//  UIWindow.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/2.
//

import UIKit

extension UIWindow {
    static var shutUpKeyWindow: UIWindow? {
        UIApplication
            .shared
            .connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter(\.isKeyWindow)
            .first
    }

    var topMostViewController: UIViewController? {
        var result: UIViewController? = rootViewController
        while true {
            if let next = result?.presentedViewController {
                result = next
                continue
            }
            if let tabbar = result as? UITabBarController,
               let next = tabbar.selectedViewController
            {
                result = next
                continue
            }
            if let split = result as? UISplitViewController,
               let next = split.viewControllers.last
            {
                result = next
                continue
            }
            if let navigator = result as? UINavigationController,
               let next = navigator.viewControllers.last
            {
                result = next
                continue
            }
            break
        }
        return result
    }
}
