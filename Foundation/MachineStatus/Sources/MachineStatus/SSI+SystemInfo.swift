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
    /// 服务器 系统 信息
    struct SystemInfo: Codable, Equatable, Hashable, Identifiable {
        public var id = UUID()

        public let releaseName: String
        public let uptimeSec: Double
        public let hostname: String
        public let runningProcs: Int
        public let totalProcs: Int
        public let load1: Float
        public let load5: Float
        public let load15: Float
        public init() {
            releaseName = ""
            uptimeSec = 0
            hostname = ""
            runningProcs = 0
            totalProcs = 0
            load1 = 0
            load5 = 0
            load15 = 0
        }

        public init(release: String,
                    uptimeInSec: Double, hostname: String,
                    runningProcs: Int, totalProcs: Int,
                    load1: Float, load5: Float, load15: Float)
        {
            releaseName = release
            uptimeSec = uptimeInSec
            self.hostname = hostname
            self.runningProcs = runningProcs
            self.totalProcs = totalProcs
            self.load1 = load1
            self.load5 = load5
            self.load15 = load15
        }

        public init?(withRemote shell: NSRemoteShell) {
            func buildHostname(intake: String) -> String {
                intake.replacingOccurrences(of: "\n", with: "")
            }
            func buildUptime(intake: String) -> Double {
                let get = intake
                let raw = get
                    .components(separatedBy: " ")
                    .first ?? ""
                guard let val = Double(raw)
                else {
                    return 0
                }
                return val
            }
            func buildLoadStatus(intake: String) -> SystemLoadInternal {
                var ret = SystemLoadInternal()
                var get = intake
                while get.contains("  ") {
                    get = get.replacingOccurrences(of: "  ", with: " ")
                }
                let cut = get.components(separatedBy: " ")
                if cut.count != 5 {
                    return .init()
                } else {
                    if let l1 = Float(cut[0]), l1 != .infinity { ret.load1avg = l1 } else { return .init() }
                    if let l5 = Float(cut[1]), l5 != .infinity { ret.load5avg = l5 } else { return .init() }
                    if let l15 = Float(cut[2]), l15 != .infinity { ret.load15avg = l15 } else { return .init() }
                    let process = cut[3].components(separatedBy: "/")
                    if process.count == 2,
                       let running = Int(process[0]), // string
                       let total = Int(process[1]) // string
                    {
                        ret.runningProcess = running
                        ret.totalProcess = total
                    } else {
                        return .init()
                    }
                }
                return ret
            }
            func buildReleaseName(intake: String) -> String {
                var release = ""
                var pretty: String?
                var name: String?
                for item in intake.components(separatedBy: "\n") {
                    if item.hasPrefix("PRETTY_NAME=") {
                        pretty = String(item.dropFirst("PRETTY_NAME=".count))
                        break
                    }
                    if item.hasPrefix("NAME=") {
                        name = String(item.dropFirst("NAME=".count))
                    }
                }
                if let name = pretty {
                    if
                        (name.hasPrefix("\"") || name.hasPrefix("\"")) ||
                        (name.hasSuffix("'") || name.hasSuffix("'")),
                        name.count > 2
                    {
                        release = String(name.dropFirst().dropLast())
                    } else {
                        release = name
                    }
                } else {
                    if let name = name {
                        if
                            (name.hasPrefix("\"") || name.hasPrefix("\"")) ||
                            (name.hasSuffix("'") || name.hasSuffix("'")),
                            name.count > 2
                        {
                            release = String(name.dropFirst().dropLast())
                        } else {
                            release = name
                        }
                    } else {
                        release = "Generic Linux"
                    }
                }
                return release
            }

            let group = DispatchGroup()

            var hostname = "Unknown Host Name"
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                let intake = downloadResultFrom(shell: shell, command: .obtainHostname)
                hostname = buildHostname(intake: intake)
            }

            var uptime: Double = 0
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                let intake = downloadResultFrom(shell: shell, command: .obtainUptime)
                uptime = buildUptime(intake: intake)
            }

            var runningProcess = 0
            var totalProcess = 0
            var load1avg: Float = 0
            var load5avg: Float = 0
            var load15avg: Float = 0
            group.enter()

            DispatchQueue.global().async {
                defer { group.leave() }
                let intake = downloadResultFrom(shell: shell, command: .obtainLoadavg)
                let get = buildLoadStatus(intake: intake)
                runningProcess = get.runningProcess
                totalProcess = get.totalProcess
                load1avg = get.load1avg
                load5avg = get.load5avg
                load15avg = get.load15avg
            }

            var release = ""
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                let intake = downloadResultFrom(shell: shell, command: .obtainRelease)
                release = buildReleaseName(intake: intake)
            }

            group.wait()

            self.init(
                release: release,
                uptimeInSec: uptime,
                hostname: hostname,
                runningProcs: runningProcess,
                totalProcs: totalProcess,
                load1: load1avg,
                load5: load5avg,
                load15: load15avg
            )
        }

        public func description() -> String {
            """
            release: \(releaseName)
            uptime: \(uptimeSec) second
            hostname: \(hostname)
            running process: \(runningProcs) total: \(totalProcs)
            load1: \(load1) load5: \(load5) load15: \(load15)
            """
        }
    }

    struct SystemLoadInternal: Codable, Equatable, Hashable, Identifiable {
        public var id = UUID()

        public var runningProcess: Int = 0
        public var totalProcess: Int = 0
        public var load1avg: Float = 0
        public var load5avg: Float = 0
        public var load15avg: Float = 0
    }
}
