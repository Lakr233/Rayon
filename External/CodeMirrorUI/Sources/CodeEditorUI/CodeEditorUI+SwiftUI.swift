//
//  CodeEditorUI+SwiftUI.swift
//
//
//  Created by Lakr Aream on 2022/2/6.
//

import SwiftUI

#if canImport(AppKit)
    import AppKit

    public struct SCodeEditor: NSViewRepresentable, CodeEditor {
        public init() {}

        let correspondingView = CodeEditorView()

        public func makeNSView(context _: Context) -> some NSView {
            correspondingView
        }

        public func updateNSView(_: NSViewType, context _: Context) {}

        @discardableResult
        public func onContentChange(callback: ((String) -> Void)?) -> Self {
            correspondingView.onContentChange(callback: callback)
            return self
        }

        @discardableResult
        public func onContentHeightChange(callback: ((Double) -> Void)?) -> Self {
            correspondingView.onContentHeightChange(callback: callback)
            return self
        }

        public func setDocumentData(_ data: String) {
            correspondingView.setDocumentData(data)
        }

        public func setDocumentFont(size: Int) {
            correspondingView.setDocumentFont(size: size)
        }

        public func setDocumentLang(_ lang: String) {
            correspondingView.setDocumentLang(lang)
        }

        public func getAvailableLang() -> [String] {
            correspondingView.getAvailableLang()
        }

        public func makeReadonly() {
            correspondingView.makeReadonly()
        }

        public func requestHeightToSend() {
            correspondingView.requestHeightToSend()
        }
    }
#endif

#if canImport(UIKit)
    import UIKit
    public struct SCodeEditor: UIViewRepresentable, CodeEditor {
        public init() {}

        let correspondingView = CodeEditorView()

        public func makeUIView(context _: Context) -> some UIView {
            correspondingView
        }

        public func updateUIView(_: UIViewType, context _: Context) {}

        @discardableResult
        public func onContentChange(callback: ((String) -> Void)?) -> Self {
            correspondingView.onContentChange(callback: callback)
            return self
        }

        @discardableResult
        public func onContentHeightChange(callback: ((Double) -> Void)?) -> Self {
            correspondingView.onContentHeightChange(callback: callback)
            return self
        }

        public func setDocumentData(_ data: String) {
            correspondingView.setDocumentData(data)
        }

        public func setDocumentFont(size: Int) {
            correspondingView.setDocumentFont(size: size)
        }

        public func setDocumentLang(_ lang: String) {
            correspondingView.setDocumentLang(lang)
        }

        public func getAvailableLang() -> [String] {
            correspondingView.getAvailableLang()
        }

        public func makeReadonly() {
            correspondingView.makeReadonly()
        }

        public func requestHeightToSend() {
            correspondingView.requestHeightToSend()
        }
    }
#endif

public struct DynamicHeightCodeView: View {
    public init(loadCode: @escaping () -> (String)) {
        self.loadCode = loadCode
    }

    var loadCode: () -> (String)
    let codeView: SCodeEditor = .init()

    @State var codeWindowHeight: Double = 200

    public var body: some View {
        codeView
            .frame(maxWidth: .infinity)
            .frame(height: codeWindowHeight)
            .disabled(true)
            .overlay(GeometryReader { r in
                Group {}.onChange(of: r.size) { _ in
                    updateHeight()
                }
            })
            .onAppear {
                codeView.makeReadonly()
                codeView.setDocumentLang("swift")
                codeView.setDocumentFont(size: 10)
                codeView.onContentHeightChange { val in
                    passingNewHeight(with: val)
                }
                codeView.setDocumentData(loadCode())
            }
    }

    func updateHeight() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            codeView.requestHeightToSend()
        }
    }

    func passingNewHeight(with val: Double) {
        if val != codeWindowHeight {
            withAnimation(.interactiveSpring()) {
                codeWindowHeight = val
            }
        }
    }
}
