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
    /// 服务器 CPU 信息
    struct ProcessorInfo: Codable, Equatable, Identifiable {
        public var id = UUID()

        public var summary: ProcessPercentInfo
        public var cores: [ProcessPercentInfo]
        public init() {
            summary = ProcessPercentInfo()
            cores = []
        }

        public init(summary: ProcessPercentInfo,
                    cores: [String: ProcessPercentInfo])
        {
            self.summary = summary
            let keys = cores
                .keys
                .sorted(by: { a, b in
                    if a.count < 3 || b.count < 3 {
                        return a < b
                    }
                    if let droppedA = Int(a.dropFirst(3)),
                       let droppedB = Int(b.dropFirst(3))
                    {
                        return droppedA < droppedB
                    } else {
                        return a < b
                    }
                })
            var build: [ProcessPercentInfo] = []
            for key in keys {
                guard var core = cores[key] else {
                    continue
                }
                core.name = key
                build.append(core)
            }
            self.cores = build
        }

        public init?(withRemote shell: NSRemoteShell) {
            let comp = downloadResultFrom(shell: shell, command: .obtainProcessInfo)
                .components(separatedBy: outputSeparator)
            guard comp.count == 2 else { return nil }
            let priv = comp[0]
            let curr = comp[1]

            func createFrom(raw: String) -> (ProcessInfoElement?, [String: ProcessInfoElement]) {
                var result = [String: ProcessInfoElement]()
                var summary: ProcessInfoElement?
                for line in raw.components(separatedBy: "\n") {
                    var line = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard line.hasPrefix("cpu") else {
                        continue
                    }
                    while line.contains("  ") {
                        line = line.replacingOccurrences(of: "  ", with: " ")
                    }
                    let lineElement = line.components(separatedBy: " ")
                    guard lineElement.count == 11 else {
                        continue
                    }
                    let key = lineElement[0]
                    let element = ProcessInfoElement(
                        user: Float(lineElement[1]) ?? 0,
                        nice: Float(lineElement[2]) ?? 0,
                        system: Float(lineElement[3]) ?? 0,
                        idle: Float(lineElement[4]) ?? 0,
                        iowait: Float(lineElement[5]) ?? 0,
                        irq: Float(lineElement[6]) ?? 0,
                        softIrq: Float(lineElement[7]) ?? 0,
                        steal: Float(lineElement[8]) ?? 0,
                        guest: Float(lineElement[9]) ?? 0
                    )
                    if key == "cpu" {
                        summary = element
                    } else {
                        result[key] = element
                    }
                }
                return (summary, result)
            }

            let resultPriv = createFrom(raw: priv)
            let resultCurr = createFrom(raw: curr)

            guard let privSum = resultPriv.0,
                  let currSum = resultCurr.0
            else {
                return nil
            }
            let privAll = resultPriv.1
            let currAll = resultCurr.1

            func calculateInfo(priv: ProcessInfoElement,
                               curr: ProcessInfoElement)
                -> ProcessPercentInfo
            {
                let preAll = priv.user + priv.nice + priv.system + priv.idle + priv.iowait + priv.irq + priv.softIrq + priv.steal + priv.guest
                let nowAll = curr.user + curr.nice + curr.system + curr.idle + curr.iowait + curr.irq + curr.softIrq + curr.steal + curr.guest

                let total = nowAll - preAll
                let privUsedTotal = priv.user + priv.nice + priv.system + priv.iowait
                let currUsedTotal = curr.user + curr.nice + curr.system + curr.iowait

                return ProcessPercentInfo(
                    system: (curr.system - priv.system) / total * 100,
                    user: (curr.user - priv.user) / total * 100,
                    iowait: (curr.iowait - priv.iowait) / total * 100,
                    nice: (curr.nice - priv.nice) / total * 100,
                    sum: (currUsedTotal - privUsedTotal) / total * 100
                )
            }

            let sum: ProcessPercentInfo = calculateInfo(priv: privSum, curr: currSum)
            var resultPerCore = [String: ProcessPercentInfo]()

            for (key, priv) in privAll {
                guard let curr = currAll[key] else {
                    continue
                }
                resultPerCore[key] = calculateInfo(priv: priv, curr: curr)
            }

            self.init(summary: sum, cores: resultPerCore)
        }
    }

    /// 服务器 CPU 信息 这里全部是百分比
    struct ProcessPercentInfo: Codable, Equatable, Identifiable {
        public var id = UUID()

        public var name: String

        public var sumSystem: Float
        public var sumUser: Float
        public var sumIOWait: Float
        public var sumNice: Float
        public var sumUsed: Float
        public init() {
            name = ""
            sumSystem = 0
            sumUser = 0
            sumIOWait = 0
            sumNice = 0
            sumUsed = 0
        }

        public init(
            system: Float, user: Float,
            iowait: Float, nice: Float,
            sum: Float
        ) {
            name = ""
            sumSystem = system
            sumUser = user
            sumIOWait = iowait
            sumNice = nice
            sumUsed = sum
        }

        public func description() -> String {
            "system: \(sumSystem), user: \(sumUser), iowait: \(sumIOWait), nice: \(sumNice)"
        }
    }

    /// 服务器 CPU 的立即信息
    struct ProcessInfoElement: Codable, Equatable, Identifiable {
        public var id = UUID()

        public let user: Float
        public let nice: Float
        public let system: Float
        public let idle: Float
        public let iowait: Float
        public let irq: Float
        public let softIrq: Float
        public let steal: Float
        public let guest: Float

        public init(user: Float, nice: Float, system: Float, idle: Float, iowait: Float, irq: Float, softIrq: Float, steal: Float, guest: Float) {
            self.user = user
            self.nice = nice
            self.system = system
            self.idle = idle
            self.iowait = iowait
            self.irq = irq
            self.softIrq = softIrq
            self.steal = steal
            self.guest = guest
        }

        public func description() -> String {
            """
            user: \(user)
            nice: \(nice)
            system: \(system)
            idle: \(idle)
            iowait: \(iowait)
            irq: \(irq)
            softIrq: \(softIrq)
            steal: \(steal)
            guest: \(guest)
            """
        }
    }
}
