//
//  CodeMirrorUI+Delegate.swift
//
//
//  Created by Lakr Aream on 2022/2/12.
//

import Foundation
import WebKit

class CodeMirrorDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {
    weak var userContentController: WKUserContentController?
    var navigateCompleted: Bool = false

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        navigateCompleted = true
    }

    deinit {
        // webkit's bug, still holding ref after deinit
        debugPrint("\(self) __deinit__")
        if Thread.isMainThread {
            userContentController?.removeScriptMessageHandler(forName: "callbackHandler")
        } else {
            let sem = DispatchSemaphore(value: 0)
            DispatchQueue.main.async { [self] in
                defer { sem.signal() }
                self.userContentController?.removeScriptMessageHandler(forName: "callbackHandler")
            }
            sem.wait()
        }
    }
}
