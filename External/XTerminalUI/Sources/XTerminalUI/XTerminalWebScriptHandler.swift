//
//  XTerminalWebScriptHandler.swift
//
//
//  Created by Lakr Aream on 2022/2/6.
//

import Foundation
import WebKit

class XTerminalWebScriptHandler: NSObject, WKScriptMessageHandler {
    var onBellChain: (() -> Void)?
    var onTitleChain: ((String) -> Void)?
    var onDataChain: ((String) -> Void)?

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
        case "bell":
            onBellChain?()
        case "title":
            onTitleChain?(msg)
        case "data":
            onDataChain?(msg)
        default:
            debugPrint("unrecognized message magic")
            debugPrint(message.body)
        }
    }

    deinit {
        debugPrint("\(self) __deinit__")
        onBellChain = nil
        onDataChain = nil
        onTitleChain = nil
    }
}
