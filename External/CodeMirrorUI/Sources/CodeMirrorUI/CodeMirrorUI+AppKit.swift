//
//  CodeMirrorUI+AppKit.swift
//
//
//  Created by Lakr Aream on 2022/2/12.
//

#if canImport(AppKit)
    import AppKit

    public class CodeEditorView: NSView, CodeEditor {
        private let associatedCore = CodeEditorCore()

        public required init() {
            super.init(frame: CGRect())
            addSubview(associatedCore.associatedWebView)
            associatedCore.associatedWebView.bindFrameToSuperviewBounds()
        }

        @available(*, unavailable)
        public required init?(coder _: NSCoder) {
            fatalError("unavailable")
        }

        @discardableResult
        public func onContentChange(callback: ((String) -> Void)?) -> Self {
            associatedCore.onContentChange(callback: callback)
            return self
        }

        public func setDocumentData(_ data: String) {
            associatedCore.setDocumentData(data)
        }

        public func setDocumentFont(size: Int) {
            associatedCore.setDocumentFont(size: size)
        }
    }

    extension NSView {
        /// Adds constraints to this `NSView` instances `superview` object to make sure this always has the same size as the superview.
        /// Please note that this has no effect if its `superview` is `nil` – add this `NSView` instance as a subview before calling this.
        func bindFrameToSuperviewBounds() {
            guard let superview = superview else {
                print("Error! `superview` was nil – call `addSubview(view: UIView)` before calling `bindFrameToSuperviewBounds()` to fix this.")
                return
            }

            translatesAutoresizingMaskIntoConstraints = false
            topAnchor.constraint(equalTo: superview.topAnchor, constant: 0).isActive = true
            bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: 0).isActive = true
            leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: 0).isActive = true
            trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: 0).isActive = true
        }
    }

#endif
