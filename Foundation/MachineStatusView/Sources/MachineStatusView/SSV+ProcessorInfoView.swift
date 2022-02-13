//
//  ProcessorInfoView.swift
//
//
//  Created by Lakr Aream on 2022/3/2.
//

import MachineStatus
import SwiftUI

public extension ServerStatusViews {
    struct ProcessorInfoView: View {
        let title: String
        let info: ServerStatus.ProcessPercentInfo

        public var body: some View {
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
}
