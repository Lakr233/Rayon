//
//  File.swift
//
//
//  Created by Lakr Aream on 2022/3/2.
//

import MachineStatus
import SwiftUI

public extension ServerStatusViews {
    struct FileSystemView: View {
        @EnvironmentObject var info: ServerStatus

        public init() {}

        var elements: [ServerStatus.FileSystemInfo.FileSystemInfoElement] {
            info.fileSystem.elements
        }

        public var body: some View {
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
}
