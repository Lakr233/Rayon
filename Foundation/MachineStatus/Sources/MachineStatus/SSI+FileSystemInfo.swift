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
    /// 服务器 文件系统 信息
    struct FileSystemInfo: Codable, Equatable, Hashable, Identifiable {
        public var id = UUID()

        public let elements: [FileSystemInfoElement]

        public struct FileSystemInfoElement: Codable, Equatable, Hashable, Identifiable {
            public var id = UUID()

            public let mountPoint: String
            public let size: String
            public let used: String
            public let free: String
            public let percent: Float

            public init() {
                mountPoint = ""
                size = ""
                used = ""
                free = ""
                percent = 0
            }

            public init(mountPoint: String, size: String, used: String, free: String, percent: Float) {
                self.mountPoint = mountPoint
                self.size = size
                self.used = used
                self.free = free
                self.percent = percent
            }

            public func description() -> String {
                """
                mount point: \(mountPoint)
                used: \(used) free: \(free) total: \(size)
                """
            }
        }

        public init() {
            elements = []
        }

        public init(elements: [FileSystemInfoElement]) {
            self.elements = elements
        }

        public init?(withRemote shell: NSRemoteShell) {
            let downloadResult = downloadResultFrom(shell: shell, command: .obtainFileSystemInfo)
            /*
             Filesystem      Size  Used Avail Use% Mounted on
             udev            935M     0  935M   0% /dev
             */
            var result = [FileSystemInfoElement]()
            for line in downloadResult.components(separatedBy: "\n").dropFirst() where line.count > 0 {
                var line = line
                while line.contains("  ") {
                    line = line.replacingOccurrences(of: "  ", with: " ")
                }
                let cut = line.components(separatedBy: " ")
                if cut.count != 6 {
                    continue
                }
                if cut[3] == "0" || cut[4].last != "%" || cut[5].first != "/" {
                    continue
                }
                let size = cut[1]
                let used = cut[2]
                let free = cut[3]
                let mount = cut[5]
                var percentStr = cut[4]
                percentStr.removeLast()
                guard let percent = Float(percentStr) else {
                    continue
                }
                result.append(.init(mountPoint: mount, size: size, used: used, free: free, percent: percent))
            }
            result = result.sorted(by: { a, b in
                a.mountPoint < b.mountPoint
            })
            self.init(elements: result)
        }
    }
}
