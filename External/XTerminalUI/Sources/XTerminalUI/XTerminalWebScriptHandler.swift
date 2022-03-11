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
    var onSizeChain: ((CGSize) -> Void)?

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
        case "size":
            if let size = ResizeData.fromString(msg) {
                onSizeChain?(size)
            }
        default:
            debugPrint("unrecognized message magic")
            debugPrint(message.body)
        }
    }

    struct ResizeData: Codable {
        var cols: Int
        var rows: Int
        static func fromString(_ str: String) -> CGSize? {
            if let data = str.data(using: .utf8),
               let dec = try? JSONDecoder().decode(ResizeData.self, from: data)
            {
                return .init(width: dec.cols, height: dec.rows)
            }
            return nil
        }
    }

    deinit {
        debugPrint("\(self) __deinit__")
        onBellChain = nil
        onDataChain = nil
        onTitleChain = nil
        onSizeChain = nil
    }
}
