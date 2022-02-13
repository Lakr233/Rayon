//
//  BatchTerminalView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/13.
//

import SwiftUI
import XTerminalUI

struct BatchTerminalView: View {
    let machine: RDRemoteMachine.ID

    @EnvironmentObject var context: BatchSnippetExecContext

    let timer = Timer
        // 要那么德芙干啥？
        .publish(every: 0.25, on: .main, in: .common)
        .autoconnect()

    // change both or stay steady
    let terminalId = UUID()
    let terminalView = STerminalView()

    var body: some View {
        GeometryReader { r in
            terminalView
                .frame(width: r.size.width, height: r.size.height)
        }
        .padding(5)
        .onReceive(timer) { _ in
            terminalView.write(context.requestBuffer(for: terminalId, machine: machine))
        }
    }
}
