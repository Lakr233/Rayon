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

/// Not actually a Actor but I like it
/// - Parameter run: the job to be fired on main thread
func mainActor(delay: Double = 0, run: @escaping () -> Void) {
    guard delay == 0, Thread.isMainThread else {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            run()
        }
        return
    }
    run()
}

public class ServerStatus: ObservableObject, Equatable {
    public init() {}

    static let outputSeparator = "[*******]"

    enum ScriptCollection: String, CaseIterable {
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

    static func downloadResultFrom(shell: NSRemoteShell, command: ScriptCollection) -> String {
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

    @Published public var processor: ProcessorInfo = .init()
    @Published public var fileSystem: FileSystemInfo = .init()
    @Published public var memory: MemoryInfo = .init()
    @Published public var system: SystemInfo = .init()
    @Published public var network: NetworkInfo = .init()

    // not all server have gpu, bro
    @Published public var graphics: GraphicsInfo? = nil

    public static func == (lhs: ServerStatus, rhs: ServerStatus) -> Bool {
        lhs.processor == rhs.processor &&
            lhs.fileSystem == rhs.fileSystem &&
            lhs.memory == rhs.memory &&
            lhs.system == rhs.system &&
            lhs.network == rhs.network &&
            lhs.graphics == rhs.graphics
    }

    public func requestInfoAndWait(with remote: NSRemoteShell) {
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
            let info = GraphicsInfo(withRemote: remote)
            mainActor { [weak self] in
                self?.graphics = info
            }
        }
        group.wait()
    }
}
