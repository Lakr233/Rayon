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

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigateCompleted = true
    }

    deinit {
        // webkit's bug, still holding ref after deinit
        debugPrint("\(self) __deinit__")
        userContentController?.removeScriptMessageHandler(forName: "callbackHandler")
    }
}
