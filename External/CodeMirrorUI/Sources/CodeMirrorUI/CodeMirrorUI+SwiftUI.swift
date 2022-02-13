//
//  CodeMirrorUI+SwiftUI.swift
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

        public func setDocumentData(_ data: String) {
            correspondingView.setDocumentData(data)
        }
        
        public func setDocumentFont(size: Int) {
            correspondingView.setDocumentFont(size: size)
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

        public func setDocumentData(_ data: String) {
            correspondingView.setDocumentData(data)
        }
        
        public func setDocumentFont(size: Int) {
            correspondingView.setDocumentFont(size: size)
        }
    }
#endif
