//
//  Template.swift
//
//
//  Created by Lakr Aream on 2022/3/2.
//

import Combine
import Foundation
import NSRemoteShell
import XMLCoder

public extension ServerStatus {
    /// 服务器 NET 信息
    struct NetworkInfo: Codable, Equatable, Hashable, Identifiable {
        public var id = UUID()

        public let elements: [NetworkInfoElement]

        public struct NetworkInfoElement: Codable, Equatable, Hashable, Identifiable {
            public var id = UUID()

            public let device: String
            public let rxBytesPerSec: Int
            public let txBytesPerSec: Int

            public init(device: String, rxBytesPerSec: Int, txBytesPerSec: Int) {
                self.device = device
                self.rxBytesPerSec = rxBytesPerSec
                self.txBytesPerSec = txBytesPerSec
            }

            public func description() -> String {
                """
                interface: \(device)
                rxBytes: \(rxBytesPerSec)/s txBytes: \(txBytesPerSec)/s
                """
            }
        }

        public init() {
            elements = []
        }

        public init(elements: [NetworkInfoElement]) {
            self.elements = elements
        }

        public init?(withRemote shell: NSRemoteShell) {
            let downloadResult = downloadResultFrom(shell: shell, command: .obtainNetworkInfo)
            let sep = downloadResult.components(separatedBy: outputSeparator)
            if sep.count != 2 { return nil }
            let priv = sep[0]
            let curr = sep[1]

            typealias RxTxPair = (Int, Int)

            func build(str: String) -> [String: RxTxPair] {
                var result = [String: RxTxPair]()
                go: for item in str.components(separatedBy: "\n") where item.contains(":") {
                    let sepName = item.components(separatedBy: ":")
                    if sepName.count != 2 {
                        continue go
                    }
                    guard var key = sepName.first,
                          var payload = sepName.last
                    else {
                        continue go
                    }
                    while key.hasPrefix(" ") {
                        key.removeFirst()
                    }
                    while key.hasSuffix(" ") {
                        key.removeLast()
                    }
                    while payload.contains("  ") {
                        payload = payload.replacingOccurrences(of: "  ", with: " ")
                    }
                    while payload.hasPrefix(" ") {
                        payload.removeFirst()
                    }
                    while payload.hasSuffix(" ") {
                        payload.removeLast()
                    }
                    let split = payload.components(separatedBy: " ")
                    if split.count < 10 {
                        continue go
                    }
                    // 0     1       2    3    4    5     6          7
                    // bytes packets errs drop fifo frame compressed multicast
                    // 8     9       10   11   12   13    14      15
                    // bytes packets errs drop fifo colls carrier compressed
                    guard let rxBytes = Int(split[0]), // string
                          let txBytes = Int(split[8]) // string
                    else {
                        continue go
                    }
                    if result[key] != nil {
                        result.removeValue(forKey: key)
                        continue
                    }
                    result[key] = (rxBytes, txBytes)
                }
                return result
            }

            let getPriv = build(str: priv)
            let getCurr = build(str: curr)
            var result = [NetworkInfoElement]()
            for item in getPriv {
                if let target = getCurr[item.key] {
                    let rxIncrease = target.0 - item.value.0
                    let txIncrease = target.1 - item.value.1
                    if rxIncrease < 0 || txIncrease < 0 {
                        continue
                    }
                    result.append(NetworkInfoElement(device: item.key, rxBytesPerSec: rxIncrease, txBytesPerSec: txIncrease))
                }
            }

            self.init(elements: result.sorted(by: { a, b in
                a.device < b.device
            }))
        }
    }
}
