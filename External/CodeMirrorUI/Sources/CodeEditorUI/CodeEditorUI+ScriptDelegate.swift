//
//  CodeEditorUI+ScriptDelegate.swift
//
//
//  Created by Lakr Aream on 2022/2/12.
//

import Foundation
import WebKit

class CodeEditorScriptHandler: NSObject, WKScriptMessageHandler {
    var onContentChange: ((String) -> Void)?
    var onContentHeightChange: ((Double) -> Void)?

    func userContentController(
        _: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let value = message.body as? [String: Any],
              let magic = value["magic"] as? String,
              let msg = value["msg"] as? String
        else {
            return
        }
        switch magic {
        case "content":
            onContentChange?(msg)
        case "height":
            if let value = Double(msg) {
                onContentHeightChange?(value)
            } else {
                debugPrint("unrecognized message \(msg)")
            }
        default:
            debugPrint("unrecognized message magic")
            debugPrint(message.body)
        }
    }

    deinit {
        onContentChange = nil
        onContentHeightChange = nil
    }
}
