//
//  GraphicsView.swift
//
//
//  Created by Lakr Aream on 2022/3/2.
//

import MachineStatus
import SwiftUI

public extension ServerStatusViews {
    struct GraphicsView: View {
        @EnvironmentObject var info: ServerStatus

        public init() {}

        public var body: some View {
            Group {
                if let graphics = info.graphics {
                    buildGraphics(from: graphics)
                }
            }
        }

        func buildGraphics(from: ServerStatus.GraphicsInfo) -> some View {
            VStack {
                HStack {
                    Image(systemName: "n.circle.fill")
                    Text("GPU")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                }
                Divider()
                if from.units.isEmpty {
                    Text("No GPU Available")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                } else {
                    VStack(spacing: 12) {
                        ForEach(from.units) { element in
                            createView(for: element)
                        }
                    }
                }
                Divider()
                HStack {
                    Text("Driver Version: " + from.version)
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                    Spacer()
                }
                .opacity(0.5)
            }
        }

        func createView(for element: ServerStatus.SingleGraphicsInfo) -> some View {
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "arrow.right")
                    Text(element.name)
                        .font(.system(size: 12, weight: .bold, design: .default))
                    Spacer()
                }
                HStack {
                    HStack(spacing: 0) {
                        Text("GPU: " + gpuPercentDescription(for: element))
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(element.utilization.gpu_util > 75 ? .red : .blue)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .frame(width: 85)
                    ColorizedProgressView(
                        colors: [
                            .init(color: .yellow, weight: element.utilization.gpu_util),
                            .init(color: .green, weight: 100 - element.utilization.gpu_util),
                        ]
                    )
                }
                HStack {
                    HStack(spacing: 0) {
                        Text("RAM: " + ramPercentDescription(for: element))
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor((element.memory.used / element.memory.total) * 100 > 75 ? .red : .blue)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .frame(width: 85)
                    ColorizedProgressView(
                        colors: [
                            .init(color: .yellow, weight: element.memory.used),
                            .init(color: .green, weight: element.memory.free),
                        ]
                    )
                }
                HStack {
                    Text("vbios: " + element.vbios_version)
                    Text("fan: " + element.fan_speed)
                    Spacer()
                }
                .font(.system(size: 10, weight: .regular, design: .monospaced))
            }
        }

        func gpuPercentDescription(for unit: ServerStatus.SingleGraphicsInfo) -> String {
            Float(unit.utilization.gpu_util)
                .string(fractionDigits: 2) + " %"
        }

        func ramPercentDescription(for unit: ServerStatus.SingleGraphicsInfo) -> String {
            Float((unit.memory.used / unit.memory.total) * 100)
                .string(fractionDigits: 2) + " %"
        }
    }
}
