//
//  SwiftUIView.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/2/9.
//

import SwiftUI

enum SheetTemplate {
    typealias Confirmed = Bool

    static func makeSheet(
        title: String,
        body: AnyView,
        complete: @escaping (Confirmed) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            Divider()
            body.expended()
            Divider()
            HStack {
                Button { complete(false) } label: { Text("Cancel") }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button { complete(true) } label: { Text("Done") }
            }
        }
        .padding()
    }

    static func makeProgress(text: String) -> some View {
        ProgressView(text)
            .frame(width: 400, height: 200)
    }

    static func makeErrorAlert(with error: Error, delay: Double = 0) {
        mainActor(delay: delay) {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = error.localizedDescription
            alert.addButton(withTitle: "Done")
            alert.beginSheetModal(for: NSApp.keyWindow ?? NSWindow()) { _ in
            }
        }
    }
}
