//
//  CodeMirrorUI.swift
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

    func setDocumentData(_ data: String)

    func setDocumentFont(size: Int)
}

class CodeEditorCore: CodeEditor {
    let associatedWebView: TransparentWebView
    let associatedWebDelegate: CodeMirrorDelegate
    let associatedScriptDelegate: CodeMirrorScriptHandler

    init() {
        associatedWebDelegate = CodeMirrorDelegate()
        associatedScriptDelegate = CodeMirrorScriptHandler()
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
        associatedWebView = TransparentWebView(frame: .zero, configuration: configuration)
        associatedWebView.uiDelegate = associatedWebDelegate
        associatedWebView.navigationDelegate = associatedWebDelegate

        #if os(macOS)
            associatedWebView.setValue(false, forKey: "drawsBackground")
            if #available(macOS 12.0, *) {
                associatedWebView.underPageBackgroundColor = .clear
            }
            associatedWebView.layer?.backgroundColor = .clear
        #else
            associatedWebView.backgroundColor = UIColor.clear
            associatedWebView.scrollView.backgroundColor = UIColor.clear
        #endif

        guard let resources = Bundle
            .module
            .url(
                forResource: "index",
                withExtension: "html",
                subdirectory: "ress"
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
    func onContentChange(callback: ((String) -> Void)?) -> Self {
        associatedScriptDelegate.onContentChange = callback
        return self
    }

    func setDocumentData(_ doc: String) {
        setDocumentData(doc, retry: 3)
    }

    func evaluateJavaScript(_ script: String, withError: @escaping (Error) -> Void) {
        DispatchQueue.global().async { [weak self] in
            while !(self?.associatedWebDelegate.navigateCompleted ?? true) { usleep(1000) }
            DispatchQueue.main.async { [weak self] in
                self?.associatedWebView.evaluateJavaScript(script) { _, error in
                    // TODO: FIXME: ****
                    if let error = error {
                        print(error.localizedDescription)
                        print(script)
                        withError(error)
                    }
                }
            }
        }
    }

    func setDocumentData(_ doc: String, retry: Int) {
        guard let data = doc.data(using: .utf8) else {
            return
        }
        guard retry >= 0 else { return }
        let base64 = data.base64EncodedString()
        let script = "setText(atob('\(base64)'))"
        evaluateJavaScript(script) { _ in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.setDocumentData(doc, retry: retry - 1)
            }
        }
    }

    public func setDocumentFont(size: Int) {
        setDocumentFont(size: size, retry: 3)
    }
    
    public func setDocumentFont(size: Int, retry: Int) {
        guard retry >= 0 else { return }
        let script = "window.setSize(\(size))"
        evaluateJavaScript(script) { _ in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.setDocumentFont(size: size, retry: retry - 1)
            }
        }
        
    }
}
