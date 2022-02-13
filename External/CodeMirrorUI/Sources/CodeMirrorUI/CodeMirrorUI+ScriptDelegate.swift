//
//  CodeMirrorUI+ScriptDelegate.swift
//
//
//  Created by Lakr Aream on 2022/2/12.
//

import Foundation
import WebKit

class CodeMirrorScriptHandler: NSObject, WKScriptMessageHandler {
    var onContentChange: ((String) -> Void)?

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
        default:
            debugPrint("unrecognized message magic")
            debugPrint(message.body)
        }
    }

    deinit {
        debugPrint("\(self) __deinit__")
        onContentChange = nil
    }
}
