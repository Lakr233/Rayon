//
//  ProcessorInfoSummaryView.swift
//
//
//  Created by Lakr Aream on 2022/3/2.
//

import MachineStatus
import SwiftUI

public extension ServerStatusViews {
    struct ProcessorInfoSummaryView: View {
        @EnvironmentObject var info: ServerStatus

        public init() {}

        public var body: some View {
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
}
