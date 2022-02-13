//
//  FilePicker.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/2.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

public struct FilePicker<LabelView: View>: View {
    public typealias PickedURLsCompletionHandler = (_ urls: [URL]) -> Void
    public typealias LabelViewContent = () -> LabelView

    @State private var isPresented: Bool = false

    public let types: [UTType]
    public let allowMultiple: Bool
    public let pickedCompletionHandler: PickedURLsCompletionHandler
    public let labelViewContent: LabelViewContent

    public init(types: [UTType], allowMultiple: Bool, onPicked completionHandler: @escaping PickedURLsCompletionHandler, @ViewBuilder label labelViewContent: @escaping LabelViewContent) {
        self.types = types
        self.allowMultiple = allowMultiple
        pickedCompletionHandler = completionHandler
        self.labelViewContent = labelViewContent
    }

    public init(types: [UTType], allowMultiple: Bool, title: String, onPicked completionHandler: @escaping PickedURLsCompletionHandler) where LabelView == Text {
        self.init(types: types, allowMultiple: allowMultiple, onPicked: completionHandler) { Text(title) }
    }

    public var body: some View {
        Button(
            action: {
                if !isPresented { isPresented = true }
            },
            label: {
                labelViewContent()
            }
        )
        .disabled(isPresented)
        .sheet(isPresented: $isPresented) {
            FilePickerUIRepresentable(types: types, allowMultiple: allowMultiple, onPicked: pickedCompletionHandler)
        }
    }
}

public struct FilePickerUIRepresentable: UIViewControllerRepresentable {
    public typealias UIViewControllerType = UIDocumentPickerViewController
    public typealias PickedURLsCompletionHandler = (_ urls: [URL]) -> Void

    @Environment(\.presentationMode) var presentationMode

    public let types: [UTType]
    public let allowMultiple: Bool
    public let pickedCompletionHandler: PickedURLsCompletionHandler

    public init(types: [UTType], allowMultiple: Bool, onPicked completionHandler: @escaping PickedURLsCompletionHandler) {
        self.types = types
        self.allowMultiple = allowMultiple
        pickedCompletionHandler = completionHandler
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = allowMultiple
        return picker
    }

    public func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: FilePickerUIRepresentable

        init(parent: FilePickerUIRepresentable) {
            self.parent = parent
        }

        public func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.pickedCompletionHandler(urls)
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
