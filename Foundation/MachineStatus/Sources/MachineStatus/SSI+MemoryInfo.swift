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
    /// 服务器 RAM 信息
    struct MemoryInfo: Codable, Equatable, Identifiable {
        public var id = UUID()

        public let memTotal: Float
        public let memFree: Float
        public let memBuffers: Float
        public let memCached: Float
        public let swapTotal: Float
        public let swapFree: Float
        public let phyUsed: Float
        public let swapUsed: Float
        public init() {
            memTotal = 0
            memFree = 0
            memBuffers = 0
            memCached = 0
            swapTotal = 0
            swapFree = 0
            phyUsed = 0
            swapUsed = 0
        }

        public init(total: Float, free: Float, buffers: Float, cached: Float, swapTotal: Float, swapFree: Float) {
            memTotal = total
            memFree = free
            memBuffers = buffers
            memCached = cached
            self.swapTotal = swapTotal
            self.swapFree = swapFree
            if total != 0 {
                phyUsed = (
                    (total - free - memCached - memBuffers) / total
                )
                swapUsed = (
                    (swapTotal - swapFree) / total
                )
            } else {
                phyUsed = 0
                swapUsed = 0
            }
        }

        public init?(withRemote shell: NSRemoteShell) {
            let downloadResult = downloadResultFrom(shell: shell, command: .obtainMemoryInfo)
            var info = [String: Float]()
            for line in downloadResult.components(separatedBy: "\n") where line.count > 0 {
                var line = line
                while line.contains("  ") {
                    line = line.replacingOccurrences(of: "  ", with: " ")
                }
                line = line.replacingOccurrences(of: ":", with: "")
                let cut = line.components(separatedBy: " ")
                switch cut.count {
                case 2:
                    continue
                case 3:
                    if cut[2].uppercased() == "KB" {
                        info[cut[0].uppercased()] = Float(cut[1])
                    }
                default:
                    continue
                }
            }
            self.init(
                total: info["MemTotal".uppercased()] ?? 0,
                free: info["MemFree".uppercased()] ?? 0,
                buffers: info["Buffers".uppercased()] ?? 0,
                cached: info["Cached".uppercased()] ?? 0,
                swapTotal: info["SwapTotal".uppercased()] ?? 0,
                swapFree: info["SwapFree".uppercased()] ?? 0
            )
        }

        public func description() -> String {
            """
            total: \(Int(exactly: memTotal) ?? 0) kB
            free: \(Int(exactly: memFree) ?? 0) kB
            buffers: \(Int(exactly: memBuffers) ?? 0) kB
            cached: \(Int(exactly: memCached) ?? 0) kB
            swap: \(Int(exactly: swapFree) ?? 0)/\(Int(exactly: swapTotal) ?? 0) kB
            """
        }
    }
}
