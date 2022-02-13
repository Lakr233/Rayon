//
//  File.swift
//
//
//  Created by Lakr Aream on 2022/3/2.
//

import MachineStatus
import SwiftUI

public extension ServerStatusViews {
    struct MemoryInfoView: View {
        @EnvironmentObject var info: ServerStatus

        public init() {}

        public var body: some View {
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
                Divider()
                HStack {
                    Text("Active & Inactive is not counted as free memory")
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                    Spacer()
                }
                .opacity(0.5)
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
}
