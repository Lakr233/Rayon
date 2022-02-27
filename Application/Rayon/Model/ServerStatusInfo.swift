//
//  ServerInfo.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/12.
//

import Combine
import Foundation
import NSRemoteShell
import XMLCoder

private let outputSeparator = "[*******]"

private enum ScriptCollection: String, CaseIterable {
    case obtainProcessInfo =
        """
         /bin/cat /proc/stat && /bin/sleep 1 && echo '[*******]' && /bin/cat /proc/stat
        """
    case obtainMemoryInfo =
        """
         /bin/cat /proc/meminfo
        """
    case obtainFileSystemInfo =
        """
         /bin/df -h
        """
    case obtainHostname =
        """
         ([ -f /proc/sys/kernel/hostname ] && cat /proc/sys/kernel/hostname )|| echo "localhost"
        """
    case obtainUptime =
        """
         /bin/cat /proc/uptime
        """
    case obtainLoadavg =
        """
         /bin/cat /proc/loadavg
        """
    case obtainRelease =
        """
         /bin/cat /etc/os-release
        """
    case obtainNetworkInfo =
        """
         /bin/cat /proc/net/dev && /bin/sleep 1 && echo '[*******]' && /bin/cat /proc/net/dev
        """
    case obtainGraphicsInfo =
        """
         nvidia-smi -q -x | tr -d "[\t\n]" || echo "no nvidia gpu available"
        """
}

private func downloadResultFrom(shell: NSRemoteShell, command: ScriptCollection) -> String {
    guard shell.isConnected, shell.isAuthenicated else {
        return ""
    }
    var result = ""
    shell.executeRemote(
        command.rawValue,
        withExecTimeout: NSNumber(value: 0),
        withOutput: { result.append($0) },
        withContinuationHandler: nil
    )
    return result
}

class ServerStatus: ObservableObject, Equatable {
    @Published var processor: ProcessorInfo = .init()
    @Published var fileSystem: FileSystemInfo = .init()
    @Published var memory: MemoryInfo = .init()
    @Published var system: SystemInfo = .init()
    @Published var network: NetworkInfo = .init()
    @Published var graphics: GraphicsInfo = .init()

    static func == (lhs: ServerStatus, rhs: ServerStatus) -> Bool {
        lhs.processor == rhs.processor &&
            lhs.fileSystem == rhs.fileSystem &&
            lhs.memory == rhs.memory &&
            lhs.system == rhs.system &&
            lhs.network == rhs.network &&
            lhs.graphics == rhs.graphics
    }

    func requestInfoAndWait(with remote: NSRemoteShell) {
        #if DEBUG
            for script in ScriptCollection.allCases {
                guard script.rawValue.hasPrefix(" ") else {
                    fatalError(
                        """

                        [E] Script: [\(script)]
                            All script within the app should start with space ' '
                            to avoid storing into remote history

                        """
                    )
                }
            }
        #endif

        let group = DispatchGroup()
        let queue = DispatchQueue(label: "wiki.qaq.rayon.info", attributes: .concurrent)
        group.enter()
        queue.async { [weak self] in
            defer { group.leave() }
            let info = ProcessorInfo(withRemote: remote) ?? .init()
            mainActor { [weak self] in
                self?.processor = info
            }
        }
        group.enter()
        queue.async { [weak self] in
            defer { group.leave() }
            let info = FileSystemInfo(withRemote: remote) ?? .init()
            mainActor { [weak self] in
                self?.fileSystem = info
            }
        }
        group.enter()
        queue.async { [weak self] in
            defer { group.leave() }
            let info = MemoryInfo(withRemote: remote) ?? .init()
            mainActor { [weak self] in
                self?.memory = info
            }
        }
        group.enter()
        queue.async { [weak self] in
            defer { group.leave() }
            let info = SystemInfo(withRemote: remote) ?? .init()
            mainActor { [weak self] in
                self?.system = info
            }
        }
        group.enter()
        queue.async { [weak self] in
            defer { group.leave() }
            let info = NetworkInfo(withRemote: remote) ?? .init()
            mainActor { [weak self] in
                self?.network = info
            }
        }
        group.enter()
        queue.async { [weak self] in
            defer { group.leave() }
            let info = GraphicsInfo(withRemote: remote) ?? .init()
            mainActor { [weak self] in
                self?.graphics = info
            }
        }
        group.wait()
    }

    /// 服务器 CPU 信息
    struct ProcessorInfo: Codable, Equatable, Identifiable {
        var id = UUID()

        public var summary: ProcessPercentInfo
        public var cores: [ProcessPercentInfo]
        init() {
            summary = ProcessPercentInfo()
            cores = []
        }

        init(summary: ProcessPercentInfo,
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

        init?(withRemote shell: NSRemoteShell) {
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
        var id = UUID()

        var name: String

        public var sumSystem: Float
        public var sumUser: Float
        public var sumIOWait: Float
        public var sumNice: Float
        public var sumUsed: Float
        init() {
            name = ""
            sumSystem = 0
            sumUser = 0
            sumIOWait = 0
            sumNice = 0
            sumUsed = 0
        }

        init(
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
        var id = UUID()

        public let user: Float
        public let nice: Float
        public let system: Float
        public let idle: Float
        public let iowait: Float
        public let irq: Float
        public let softIrq: Float
        public let steal: Float
        public let guest: Float

        init(user: Float, nice: Float, system: Float, idle: Float, iowait: Float, irq: Float, softIrq: Float, steal: Float, guest: Float) {
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

    /// 服务器 RAM 信息
    struct MemoryInfo: Codable, Equatable, Identifiable {
        var id = UUID()

        public let memTotal: Float
        public let memFree: Float
        public let memBuffers: Float
        public let memCached: Float
        public let swapTotal: Float
        public let swapFree: Float
        public let phyUsed: Float
        public let swapUsed: Float
        init() {
            memTotal = 0
            memFree = 0
            memBuffers = 0
            memCached = 0
            swapTotal = 0
            swapFree = 0
            phyUsed = 0
            swapUsed = 0
        }

        init(total: Float, free: Float, buffers: Float, cached: Float, swapTotal: Float, swapFree: Float) {
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

        init?(withRemote shell: NSRemoteShell) {
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

    /// 服务器 NET 信息
    struct NetworkInfo: Codable, Equatable, Hashable, Identifiable {
        var id = UUID()

        let elements: [NetworkInfoElement]

        struct NetworkInfoElement: Codable, Equatable, Hashable, Identifiable {
            var id = UUID()

            public let device: String
            public let rxBytesPerSec: Int
            public let txBytesPerSec: Int

            init(device: String, rxBytesPerSec: Int, txBytesPerSec: Int) {
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

        init() {
            elements = []
        }

        init(elements: [NetworkInfoElement]) {
            self.elements = elements
        }

        init?(withRemote shell: NSRemoteShell) {
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

    /// 服务器 文件系统 信息
    struct FileSystemInfo: Codable, Equatable, Hashable, Identifiable {
        var id = UUID()

        let elements: [FileSystemInfoElement]

        struct FileSystemInfoElement: Codable, Equatable, Hashable, Identifiable {
            var id = UUID()

            public let mountPoint: String
            public let size: String
            public let used: String
            public let free: String
            public let percent: Float

            init() {
                mountPoint = ""
                size = ""
                used = ""
                free = ""
                percent = 0
            }

            init(mountPoint: String, size: String, used: String, free: String, percent: Float) {
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

        init() {
            elements = []
        }

        init(elements: [FileSystemInfoElement]) {
            self.elements = elements
        }

        init?(withRemote shell: NSRemoteShell) {
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

    /// 服务器 系统 信息
    struct SystemInfo: Codable, Equatable, Hashable, Identifiable {
        var id = UUID()

        public let releaseName: String
        public let uptimeSec: Int
        public let hostname: String
        public let runningProcs: Int
        public let totalProcs: Int
        public let load1: Float
        public let load5: Float
        public let load15: Float
        init() {
            releaseName = ""
            uptimeSec = 0
            hostname = ""
            runningProcs = 0
            totalProcs = 0
            load1 = 0
            load5 = 0
            load15 = 0
        }

        init(release: String,
             uptimeInSec: Int, hostname: String,
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

        init?(withRemote shell: NSRemoteShell) {
            func buildHostname(intake: String) -> String {
                intake.replacingOccurrences(of: "\n", with: "")
            }
            func buildUptime(intake: String) -> Int {
                let get = intake
                guard let ans = Double(get
                    .components(separatedBy: " ")
                    .first ?? "")
                else {
                    return 0
                }
                if ans < Double(Int.min + 5) || ans > Double(Int.max - 5) {
                    return 0
                }
                return Int(exactly: ans) ?? 0
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

            var uptime = 0
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
    
    /// 服务器 GPU 信息
    struct GraphicsInfo: Codable, Equatable, Identifiable, DynamicNodeEncoding {
        var id = UUID()
        
        public let version: String // CUDA version, like '11.2'
        public let units: [SingleGraphicsInfo]
        
        enum CodingKeys: String, CodingKey {
            case version = "cuda_version"
            case units = "gpu"
        }
        
        static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
            switch key {
            case GraphicsInfo.CodingKeys.version: return .both
            default: return .element
            }
        }
        
        init() {
            version = "unknown"
            units = []
        }
        
        init?(withRemote shell: NSRemoteShell) {
            let downloadResult = downloadResultFrom(shell: shell, command: .obtainGraphicsInfo)
            self = (try? XMLDecoder().decode(GraphicsInfo.self, from: Data(downloadResult.utf8))) ?? .init()
            // if gpu is not supported by Nvidia, init with empty ({ version: "unknown", units: [] })
        }
    }

    /// 单块 GPU 信息
    struct SingleGraphicsInfo: Codable, Equatable, Identifiable {
        var id = UUID()
        
        public let uuid: String // GPU uuid from Nvidia
        public let name: String // GPU name, like '2080 Ti'
        public let memory: Memory

        struct Memory: Codable {
            let total: Float
            let used: Float
            let free: Float
            
            init() {
                total = 0
                used = 0
                free = 0
            }
            
            init(total: Float, used: Float, free: Float) {
                self.total = total
                self.used = used
                self.free = free
            }
            
            init(from decoder: Decoder) throws {
                // 11019 MiB -> 11019
                func s2f(status: String) -> Float {
                    let tmp = status.components(separatedBy: " ")[0]
                    let num = Float(tmp) ?? 0
                    return num
                }
                // decode
                let container = try! decoder.container(keyedBy: CodingKeys.self)
                let t = try! container.decode(String.self, forKey: .total)
                let u = try! container.decode(String.self, forKey: .used)
                let f = try! container.decode(String.self, forKey: .used)
                self.init(total: s2f(status: t), used: s2f(status: u), free: s2f(status: f))
            }
        }

        enum CodingKeys: String, CodingKey {
            case uuid
            case name = "product_name"
            case memory = "fb_memory_usage"
        }
        
        init() {
            uuid = ""
            name = "unknown"
            memory = Memory()
        }
        
        static func == (lhs: SingleGraphicsInfo, rhs: SingleGraphicsInfo) -> Bool {
            lhs.id == rhs.id
        }
        
        public func description() -> String {
            """
            uuid: \(uuid) name: \(name)
            used: \(memory.used) free: \(memory.free) \total: \(memory.total)
            """
        }
    }



    struct SystemLoadInternal: Codable, Equatable, Hashable, Identifiable {
        var id = UUID()

        var runningProcess: Int = 0
        var totalProcess: Int = 0
        var load1avg: Float = 0
        var load5avg: Float = 0
        var load15avg: Float = 0
    }
}
