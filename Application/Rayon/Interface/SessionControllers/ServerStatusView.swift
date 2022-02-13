//
//  ServerStatusView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/12.
//

import SwiftUI

private func memoryFmt(KBytes: Float) -> String {
    bytesFmt(bytes: Int(exactly: KBytes * 1000) ?? 0)
}

private func bytesFmt(bytes: Int) -> String {
    let fmt = ByteCountFormatter()
    return fmt.string(fromByteCount: Int64(exactly: bytes) ?? 0)
}

enum ServerStatusViews {
    struct SystemInfo: View {
        @EnvironmentObject var info: ServerStatus

        var body: some View {
            VStack {
                HStack {
                    Image(systemName: "gyroscope")
                    Text("System".uppercased())
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                    Text(info.system.releaseName)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                }
                Divider()
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Hostname" + ":")
                        Spacer()
                        Text(info.system.hostname)
                    }
                    HStack {
                        Text("Uptime" + ":")
                        Spacer()
                        Text(obtainUptimeDescription())
                    }
                    HStack {
                        Text("Running Process" + ":")
                        Spacer()
                        Text("\(info.system.runningProcs)").font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                    HStack {
                        Text("Total Process" + ":")
                        Spacer()
                        Text("\(info.system.totalProcs)").font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                    HStack {
                        Text("Average Load 1 min" + ":")
                        Spacer()
                        Text(info.system.load1.string(fractionDigits: 4))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                    HStack {
                        Text("Average Load 5 min" + ":")
                        Spacer()
                        Text(info.system.load5.string(fractionDigits: 4))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                    HStack {
                        Text("Average Load 15 min" + ":")
                        Spacer()
                        Text(info.system.load15.string(fractionDigits: 4))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                    Divider().opacity(0)
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
        }

        func format(duration: TimeInterval) -> String {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.day, .hour, .minute, .second]
            formatter.unitsStyle = .full
            formatter.maximumUnitCount = 1
            return formatter.string(from: duration) ?? ""
        }

        func obtainUptimeDescription() -> String {
            String(Double(exactly: info.system.uptimeSec) ?? 0.0)
        }
    }

    struct ProcessorInfoSummaryView: View {
        @EnvironmentObject var info: ServerStatus

        var body: some View {
            VStack {
                HStack {
                    Image(systemName: "cpu")
                    Text("CPU")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                    Text(info.processor.cores.count > 1 ? "\(info.processor.cores.count) CORES" : "\(info.processor.cores.count) CORE")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                }
                Divider()
                ProcessorInfoView(title: "All Core", info: info.processor.summary)
                Divider()
                if info.processor.cores.count > 0 {
                    ForEach(info.processor.cores) { core in
                        ProcessorInfoView(title: core.name, info: core)
                    }
                } else {
                    Text("No Data Available")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                }
                Divider()
                LazyVGrid(columns:
                    [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], content: {
                        HStack {
                            Circle()
                                .foregroundColor(.yellow)
                                .frame(width: 10, height: 10)
                            Text("USER")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                            Spacer()
                        }
                        HStack {
                            Circle()
                                .foregroundColor(.red)
                                .frame(width: 10, height: 10)
                            Text("SYS")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                            Spacer()
                        }
                        HStack {
                            Circle()
                                .foregroundColor(.orange)
                                .frame(width: 10, height: 10)
                            Text("IO")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                            Spacer()
                        }
                        HStack {
                            Circle()
                                .foregroundColor(.blue)
                                .frame(width: 10, height: 10)
                            Text("NICE")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                            Spacer()
                        }
                    })
            }
        }
    }

    struct ProcessorInfoView: View {
        let title: String
        let info: ServerStatus.ProcessPercentInfo

        var body: some View {
            VStack(spacing: 2) {
                HStack {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .default))
                    Spacer()
                    Text(info.sumUsed.string(fractionDigits: 2) + " %")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(info.sumUsed > 75 ? .red : .blue)
                }
                ColorizedProgressView(
                    colors: [
                        .init(color: .yellow, weight: info.sumUser),
                        .init(color: .red, weight: info.sumSystem),
                        .init(color: .orange, weight: info.sumIOWait),
                        .init(color: .blue, weight: info.sumNice),
                    ],
                    reservedWeight: 100 - info.sumUsed
                )
                HStack {
                    Text(getDescription())
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                    Spacer()
                }
                Divider().opacity(0)
            }
        }

        func getDescription() -> String {
            "USER \(info.sumUser.string(fractionDigits: 2)) SYSTEM \(info.sumSystem.string(fractionDigits: 2)) IO \(info.sumIOWait.string(fractionDigits: 2)) NICE \(info.sumNice.string(fractionDigits: 2))"
        }
    }

    struct MemoryInfoView: View {
        @EnvironmentObject var info: ServerStatus
        var body: some View {
            VStack {
                HStack {
                    Image(systemName: "memorychip")
                    Text("RAM")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                    Text(memoryFmt(KBytes: info.memory.memTotal))
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                }
                Divider()
                VStack(spacing: 2) {
                    HStack {
                        Text(shortDescription())
                        Spacer()
                        Text(percentDescription())
                    }
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    ColorizedProgressView(
                        colors: [
                            // MemFree+Active+Inactive
                            .init(color: .yellow, weight: info.memory.memTotal - info.memory.memFree),
                            .init(color: .orange, weight: info.memory.memCached),
                            .init(color: .green, weight: info.memory.memFree),
                        ]
                    )
                }
                Divider()
                HStack {
                    Text("Active & Inactive is not counted as free memory.")
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                    Spacer()
                }
                .opacity(0.5)
                LazyVGrid(columns:
                    [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], content: {
                        HStack {
                            Circle()
                                .foregroundColor(.yellow)
                                .frame(width: 10, height: 10)
                            Text("USED")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                            Spacer()
                        }
                        HStack {
                            Circle()
                                .foregroundColor(.orange)
                                .frame(width: 10, height: 10)
                            Text("CACHE")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                            Spacer()
                        }
                        HStack {
                            Circle()
                                .foregroundColor(.green)
                                .frame(width: 10, height: 10)
                            Text("FREE")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                            Spacer()
                        }
                    })
            }
        }

        func shortDescription() -> String {
            "USED: \(memoryFmt(KBytes: info.memory.memTotal - info.memory.memFree)) CACHE \(memoryFmt(KBytes: info.memory.memCached)) FREE \(memoryFmt(KBytes: info.memory.memFree)) SWAP \(memoryFmt(KBytes: info.memory.swapTotal))"
        }

        func percentDescription() -> String {
            Float((1.0 - (info.memory.memFree / info.memory.memTotal)) * 100)
                .string(fractionDigits: 2) + " %"
        }
    }

    struct FileSystemView: View {
        @EnvironmentObject var info: ServerStatus

        var elements: [ServerStatus.FileSystemInfo.FileSystemInfoElement] {
            info.fileSystem.elements
        }

        var body: some View {
            VStack {
                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                    Text("DISK")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                }
                Divider()
                if elements.count == 0 {
                    Text("No Data Available")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                } else {
                    elementsStack
                }
                Divider()
                HStack {
                    Text("Mount point may be inaccurate due to system limit")
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                    Spacer()
                }
                .opacity(0.5)
            }
        }

        var elementsStack: some View {
            VStack(spacing: 12) {
                ForEach(elements) { element in
                    VStack(spacing: 6) {
                        HStack {
                            Text(element.mountPoint)
                                .font(.system(size: 12, weight: .bold, design: .default))
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(element.percent.string(fractionDigits: 2) + " %")
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundColor(element.percent > 75 ? .red : .blue)
                                Text(
                                    "USED: \(element.used) FREE \(element.free)"
                                )
                            }
                            .font(.system(size: 8, weight: .regular, design: .monospaced))
                        }
                        ColorizedProgressView(
                            colors: [
                                .init(color: .yellow, weight: element.percent),
                                .init(color: .green, weight: 100.0 - element.percent),
                            ]
                        )
                    }
                }
            }
        }
    }

    struct NetworkView: View {
        @EnvironmentObject var info: ServerStatus

        var elements: [ServerStatus.NetworkInfo.NetworkInfoElement] {
            info.network.elements
        }

        var totalRxByte: Int {
            var result = 0
            info.network.elements.map(\.rxBytesPerSec).forEach { value in
                result &+= value
            }
            return result
        }

        var totalTxByte: Int {
            var result = 0
            info.network.elements.map(\.txBytesPerSec).forEach { value in
                result &+= value
            }
            return result
        }

        var body: some View {
            VStack {
                HStack {
                    Image(systemName: "network")
                    Text("NET")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                }
                Divider()
                VStack(spacing: 12) {
                    if elements.count > 0 {
                        ForEach(elements) { network in
                            VStack(spacing: 12) {
                                HStack {
                                    Spacer().frame(width: 2.5, height: 0)
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.orange)
                                    Text(network.device)
                                    Spacer()
                                }
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                ], content: {
                                    HStack {
                                        Image(systemName: "arrow.down")
                                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                                            .foregroundColor(.purple)
                                        Text("RX")
                                            .foregroundColor(.purple)
                                        Spacer()
                                        Text(bytesFmt(bytes: network.rxBytesPerSec))
                                        Spacer().frame(width: 5)
                                    }
                                    HStack {
                                        Spacer().frame(width: 5)
                                        Image(systemName: "arrow.up").font(.system(size: 14, weight: .heavy, design: .rounded))
                                            .foregroundColor(.blue)
                                        Text("TX")
                                            .foregroundColor(.blue)
                                        Spacer()
                                        Text(bytesFmt(bytes: network.txBytesPerSec))
                                    }
                                })
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            }
                        }
                    } else {
                        Text("No Data Available")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                    }
                }
                HStack {
                    Text("Displaying network speed, measured each second.")
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                    Spacer()
                }
                .opacity(0.5)
                Divider()
                HStack {
                    Text("RX")
                    Text(bytesFmt(bytes: totalRxByte))
                    Text("TX")
                    Text(bytesFmt(bytes: totalTxByte))
                    Spacer()
                    Text("BYTES")
                }
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
            }
        }
    }
}
