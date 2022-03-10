//
//  TerminalWebViewDelegate.swift
//
//
//  Created by Lakr Aream on 2022/2/6.
//

import Foundation
import WebKit

class XTerminalWebViewDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {
    weak var userContentController: WKUserContentController?

    var navigateCompleted: Bool = false

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        debugPrint("\(self) \(#function)")
        navigateCompleted = true
    }

    deinit {
        // webkit's bug, still holding ref after deinit
        // the buffer chain will that holds a retain to shell
        // to fool the release logic for disconnect and cleanup
        debugPrint("\(self) __deinit__")
        #if DEBUG
            if Thread.isMainThread {
                userContentController?.removeScriptMessageHandler(forName: "callbackHandler")
            } else {
                fatalError("Malformed dispatch")
            }
        #else
            if Thread.isMainThread {
                userContentController?.removeScriptMessageHandler(forName: "callbackHandler")
            }
        #endif
    }
}
