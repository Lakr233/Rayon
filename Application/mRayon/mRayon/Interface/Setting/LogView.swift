//
//  LogView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/14.
//

import StripedTextTable
import SwiftUI
import UIKit

struct LogView: View {
    var body: some View {
        UILogViewR()
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Diagnostic")
            .toolbar {
                ToolbarItem {
                    Button {
                        if let url = LogRedirect.shared.path,
                           let str = try? String(contentsOfFile: url.path),
                           !str.isEmpty
                        {
                            UIBridge.sendPasteboard(str: str)
                        }
                    } label: {
                        Label("Share Diagnostic Data", systemImage: "doc.on.doc")
                    }
                }
            }
    }

//    struct ActivityViewController: UIViewControllerRepresentable {
//        let controller: UIActivityViewController
//
//        init(itemsToShare: [Any], servicesToShareItem: [UIActivity]? = nil) {
//            self.itemsToShare = itemsToShare
//            self.servicesToShareItem = servicesToShareItem
//            controller = UIActivityViewController(
//                activityItems: itemsToShare,
//                applicationActivities: servicesToShareItem
//            )
//        }
//
//        var itemsToShare: [Any]
//        var servicesToShareItem: [UIActivity]?
//
//        func makeUIViewController(
//            context _: UIViewControllerRepresentableContext<ActivityViewController>
//        )
//            -> UIActivityViewController
//        {
//            controller
//        }
//
//        func updateUIViewController(
//            _: UIActivityViewController,
//            context _: UIViewControllerRepresentableContext<ActivityViewController>
//        ) {}
//    }

    struct UILogViewR: UIViewRepresentable {
        let view: UIView
        let controller: UIViewController

        init() {
            let controller = StripedTextTableViewController(path: LogRedirect.shared.path?.path ?? "")

            controller.autoReload = true
            controller.maximumNumberOfRows = 65535
            controller.reversed = true
            controller.allowTrash = false
            controller.allowSearch = true
            controller.allowMultiline = true
            controller.pullToReload = true
            controller.tapToCopy = false
            controller.pressToCopy = true
            controller.preserveEmptyLines = false
            controller.removeDuplicates = false
            controller.rowSeparator = "\n"

            controller.modalTransitionStyle = .coverVertical
            controller.modalPresentationStyle = .formSheet
            controller.preferredContentSize = preferredPopOverSize

            view = controller.view
            self.controller = controller
        }

        func makeUIView(context _: Context) -> UIView {
            view
        }

        func updateUIView(_: UIView, context _: Context) {}
    }
}
