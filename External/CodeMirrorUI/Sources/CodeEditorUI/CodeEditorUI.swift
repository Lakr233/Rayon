//
//  CodeEditorUI.swift
//
//
//  Created by Lakr Aream on 2022/2/12.
//

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

protocol CodeEditor {
    @discardableResult
    func onContentChange(callback: ((String) -> Void)?) -> Self
    @discardableResult
    func onContentHeightChange(callback: ((Double) -> Void)?) -> Self

    func setDocumentData(_ data: String)
    func setDocumentLang(_ lang: String)
    func getAvailableLang() -> [String]
    func setDocumentFont(size: Int)

    func makeReadonly()
    func requestHeightToSend()
}

class CodeEditorCore: CodeEditor {
    let associatedWebView: TransparentWebView
    let associatedWebDelegate: CodeEditorDelegate
    let associatedScriptDelegate: CodeEditorScriptHandler

    init() {
        associatedWebDelegate = CodeEditorDelegate()
        associatedScriptDelegate = CodeEditorScriptHandler()
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
            frame: CGRect(x: 0, y: 0, width: 0, height: 0),
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
        #endif

        guard let resources = Bundle
            .module
            .url(
                forResource: "index",
                withExtension: "html",
                subdirectory: "webpack"
            )
        else {
            debugPrint("failed to load bundle resources, check your build system")
            associatedWebDelegate.navigateCompleted = true
            return
        }
        let request = URLRequest(url: resources)
        associatedWebView.load(request)
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            // WebKit will have 3 second to load before getting suck
            self.associatedWebDelegate.navigateCompleted = true
        }
    }

    func waitForLoad() {
        assert(!Thread.isMainThread)
        let begin = Date()
        while true {
            if associatedWebDelegate.navigateCompleted { break }
            if Date().timeIntervalSince(begin) > 5 { break }
            usleep(1000)
        }
    }

    @discardableResult
    func onContentChange(callback: ((String) -> Void)?) -> Self {
        associatedScriptDelegate.onContentChange = callback
        return self
    }

    @discardableResult
    func onContentHeightChange(callback: ((Double) -> Void)?) -> Self {
        associatedScriptDelegate.onContentHeightChange = callback
        return self
    }

    func setDocumentData(_ doc: String) {
        let data = doc.data(using: .utf8) ?? Data()
        let base64 = data.base64EncodedString()
        let script = "setText(atob('\(base64)'));"
        DispatchQueue.global().async {
            self.waitForLoad()
            self.associatedWebView.evaluateJavascriptWithRetry(javascript: script)
            self.requestHeightToSend()
        }
    }

    func setDocumentLang(_ lang: String) {
        let data = lang.data(using: .utf8) ?? Data()
        let base64 = data.base64EncodedString()
        let script = "window.editor.setLanguage(atob('\(base64)'))"
        DispatchQueue.global().async {
            self.waitForLoad()
            self.associatedWebView.evaluateJavascriptWithRetry(javascript: script)
            self.requestHeightToSend()
        }
    }

    func getAvailableLang() -> [String] {
        availableLanguage
    }

    func setDocumentFont(size: Int) {
        let script = "window.editor.setFontSize(\(size))"
        DispatchQueue.global().async {
            self.waitForLoad()
            self.associatedWebView.evaluateJavascriptWithRetry(javascript: script)
            self.requestHeightToSend()
        }
    }

    func makeReadonly() {
        let script = """
        document.head.appendChild(document.createElement("style")).innerHTML=".cm-activeLine.cm-line, .cm-gutterElement.cm-activeLineGutter { background-color: transparent; }"
        window.editor.makeReadonly();
        """
        DispatchQueue.global().async {
            self.waitForLoad()
            self.associatedWebView.evaluateJavascriptWithRetry(javascript: script)
            self.requestHeightToSend()
        }
    }

    func requestHeightToSend() {
        let script = """
        window.editor.requestMeasure();
        window.webkit?.messageHandlers.callbackHandler.postMessage({ magic: 'height', msg: window.editor.viewState.contentHeight.toString() });
        """
        DispatchQueue.global().async {
            self.waitForLoad()
            self.associatedWebView.evaluateJavascriptWithRetry(javascript: script)
        }
    }
}

private let availableLanguage: [String] = [
    "shell", "sh",
    "md", "markdown",
    "python",
    "rust",
    "java",
    "javascript", "typescript",
    "cpp",
    "css", "html", "json", "xml", "sql",
    "swift",
    "yaml",
]
