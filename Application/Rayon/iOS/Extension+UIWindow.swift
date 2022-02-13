//
//  Extension+UIWindow.swift
//  Rayon (iOS)
//
//  Created by Lakr Aream on 2022/2/9.
//

import UIKit

extension UIWindow {
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
