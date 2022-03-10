//
//  SwfitUI.swift
//
//
//  Created by Lakr Aream on 2022/2/6.
//

import SwiftUI

#if canImport(AppKit)
    import AppKit

    public struct STerminalView: NSViewRepresentable, XTerminal {
        public init() {}

        let correspondingView = XTerminalView()

        public func makeNSView(context _: Context) -> some NSView {
            correspondingView
        }

        public func updateNSView(_: NSViewType, context _: Context) {}

        @discardableResult
        public func setupBufferChain(callback: ((String) -> Void)?) -> Self {
            correspondingView.setupBufferChain(callback: callback)
            return self
        }

        @discardableResult
        public func setupTitleChain(callback: ((String) -> Void)?) -> Self {
            correspondingView.setupTitleChain(callback: callback)
            return self
        }

        @discardableResult
        public func setupBellChain(callback: (() -> Void)?) -> Self {
            correspondingView.setupBellChain(callback: callback)
            return self
        }
        
        @discardableResult
        public func setupSizeChain(callback: ((CGSize) -> Void)?) -> Self {
            correspondingView.setupSizeChain(callback: callback)
            return self
        }

        public func write(_ str: String) {
            correspondingView.write(str)
        }

        public func requestTerminalSize() -> CGSize {
            correspondingView.requestTerminalSize()
        }
    }
#endif

#if canImport(UIKit)
    import UIKit

    public struct STerminalView: UIViewRepresentable {
        public init() {}

        let correspondingView = XTerminalView()

        public func makeUIView(context _: Context) -> some UIView {
            correspondingView
        }

        public func updateUIView(_: UIViewType, context _: Context) {}

        @discardableResult
        public func setupBufferChain(callback: ((String) -> Void)?) -> Self {
            correspondingView.setupBufferChain(callback: callback)
            return self
        }

        @discardableResult
        public func setupTitleChain(callback: ((String) -> Void)?) -> Self {
            correspondingView.setupTitleChain(callback: callback)
            return self
        }

        @discardableResult
        public func setupBellChain(callback: (() -> Void)?) -> Self {
            correspondingView.setupBellChain(callback: callback)
            return self
        }

        public func write(_ str: String) {
            correspondingView.write(str)
        }

        public func requestTerminalSize() -> CGSize {
            correspondingView.requestTerminalSize()
        }
    }
#endif
