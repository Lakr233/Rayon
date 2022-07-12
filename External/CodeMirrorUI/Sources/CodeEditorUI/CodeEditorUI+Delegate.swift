//
//  CodeEditorUI+Delegate.swift
//
//
//  Created by Lakr Aream on 2022/2/12.
//

import Foundation
import WebKit

class CodeEditorDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {
    weak var userContentController: WKUserContentController?
    var navigateCompleted: Bool = false

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        DispatchQueue.main.async {
            // we are setting the initial size to 0
            // delay a little bit to flag will make a explicit frame change
            // thus, the line number will be refreshed to avoid a glitch
            self.navigateCompleted = true
        }
    }

    deinit {
        // webkit's bug, still holding ref after deinit
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
