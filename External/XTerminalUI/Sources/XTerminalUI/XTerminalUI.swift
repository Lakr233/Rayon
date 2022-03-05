//
//  File.swift
//
//
//  Created by Lakr Aream on 2022/2/6.
//

import Foundation
import WebKit

#if os(macOS)
    class TransparentWebView: WKWebView {
        override var isOpaque: Bool {
            false
        }
    }
#else
    class TransparentWebView: WKWebView {}
#endif

protocol XTerminal {
    @discardableResult
    func setupBufferChain(callback: ((String) -> Void)?) -> Self

    @discardableResult
    func setupTitleChain(callback: ((String) -> Void)?) -> Self

    @discardableResult
    func setupBellChain(callback: (() -> Void)?) -> Self

    func write(_ str: String)

    func requestTerminalSize() -> CGSize
}

class XTerminalCore: XTerminal {
    let associatedWebView: TransparentWebView
    let associatedWebDelegate: XTerminalWebViewDelegate
    let associatedScriptDelegate: XTerminalWebScriptHandler

    init() {
        associatedWebDelegate = XTerminalWebViewDelegate()
        associatedScriptDelegate = XTerminalWebScriptHandler()
        let configuration = WKWebViewConfiguration()
        if #available(macOS 11.0, iOS 14.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            #if os(macOS)
                configuration.preferences.javaEnabled = true
            #endif
        }
        let contentController = WKUserContentController()
        contentController.add(associatedScriptDelegate, name: "callbackHandler")
        configuration.userContentController = contentController
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        associatedWebDelegate.userContentController = contentController
        associatedWebView = TransparentWebView(
            frame: CGRect(x: 0, y: 0, width: 500, height: 500),
            configuration: configuration
        )
        associatedWebView.uiDelegate = associatedWebDelegate
        associatedWebView.navigationDelegate = associatedWebDelegate
        #if os(macOS)
            associatedWebView.setValue(false, forKey: "drawsBackground")
            if #available(macOS 12.0, *) {
                associatedWebView.underPageBackgroundColor = .clear
            }
            associatedWebView.layer?.backgroundColor = .clear
        #else
            associatedWebView.isOpaque = false
            associatedWebView.backgroundColor = UIColor.clear
            associatedWebView.scrollView.backgroundColor = UIColor.clear
            associatedWebView.scrollView.isScrollEnabled = false
        #endif

        guard let resources = Bundle
            .module
            .url(
                forResource: "index",
                withExtension: "html",
                subdirectory: "xterm"
            )
        else {
            debugPrint("failed to load bundle resources, check your build system")
            associatedWebDelegate.navigateCompleted = true
            return
        }
        let request = URLRequest(url: resources)
        associatedWebView.load(request)
    }

    @discardableResult
    func setupBufferChain(callback: ((String) -> Void)?) -> Self {
        associatedScriptDelegate.onDataChain = callback
        return self
    }

    @discardableResult
    func setupTitleChain(callback: ((String) -> Void)?) -> Self {
        associatedScriptDelegate.onTitleChain = callback
        return self
    }

    @discardableResult
    func setupBellChain(callback: (() -> Void)?) -> Self {
        associatedScriptDelegate.onBellChain = callback
        return self
    }

    var writeBuffer: [Data] = []
    let lock = NSLock()
    let writeLock = NSLock()

    func write(_ str: String) {
        guard str.count > 0,
              let data = str.data(using: .utf8)
        else {
            return
        }
        lock.lock()
        writeBuffer.append(data)
        lock.unlock()
        DispatchQueue.global().async { [weak self] in
            self?.writeData()
        }
    }

    func writeData() {
        guard writeLock.try() else {
            return
        }
        defer { writeLock.unlock() }

        // wait for the webview to load
        while !associatedWebDelegate.navigateCompleted { usleep(1000) }

        let webView = associatedWebView

        lock.lock()
        let copy = writeBuffer
        writeBuffer = []
        lock.unlock()

        let write = copy.map { $0.base64EncodedString() }

        DispatchQueue.main.async {
            for data in write {
                let script = "term.writeBase64('\(data)');"
                webView.evaluateJavaScript(script) { _, error in
                    if let error = error {
                        debugPrint(error.localizedDescription)
                        debugPrint(script)
                    }
                }
            }
        }
    }

    func requestTerminalSize() -> CGSize {
        assert(!Thread.isMainThread, "\(#function) could not be called from main thread")
        let group = DispatchGroup()
        var col = 0
        var row = 0
        group.enter()
        let webView = associatedWebView
        DispatchQueue.main.async {
            webView.evaluateJavaScript("term.cols") { cols, _ in
                defer { group.leave() }
                guard let cols = cols as? Int else { return }
                col = cols
            }
        }
        group.enter()
        DispatchQueue.main.async {
            webView.evaluateJavaScript("term.rows") { rows, _ in
                defer { group.leave() }
                guard let rows = rows as? Int else { return }
                row = rows
            }
        }
        group.wait()
        let size = CGSize(width: col, height: row)
//        debugPrint(size)
        return size
    }
}
