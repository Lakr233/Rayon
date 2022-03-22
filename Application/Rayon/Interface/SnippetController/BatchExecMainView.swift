//
//  BatchExecMainView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/13.
//

import SwiftUI

struct BatchExecMainView: View {
    @EnvironmentObject var context: BatchSnippetExecContext

    @State var currentProgress: Double = 0
    @State var totalProgress: Double = 0

    @State var inProgressName: [String] = []
    @State var completedName: [String] = []

    let timer = Timer
        .publish(every: 1, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        progressView
            .expended()
            .frame(maxWidth: 400)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .onAppear {
                updateProgress()
            }
            .onReceive(timer) { _ in
                updateProgress()
            }
            .animation(.interactiveSpring(), value: currentProgress)
            .animation(.interactiveSpring(), value: totalProgress)
            .animation(.interactiveSpring(), value: inProgressName)
            .animation(.interactiveSpring(), value: completedName)
    }

    var progressView: some View {
        Group {
            if currentProgress == 0, totalProgress == 0 {
                ProgressView()
            } else if currentProgress < totalProgress {
                VStack(alignment: .leading, spacing: 15) {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                    ProgressView(value: currentProgress, total: totalProgress) {
                        Text("Operation is in progress: \(Int(exactly: totalProgress - currentProgress) ?? 1) remain")
                    }
                    if inProgressName.count > 0 {
                        Text("Executing: " + inProgressName.joined(separator: ", "))
                    }
                    if completedName.count > 0 {
                        Text("Completed: " + completedName.joined(separator: ", "))
                    }
                }
            } else if currentProgress == totalProgress {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50, weight: .semibold, design: .rounded))
                        .foregroundColor(.green)
                        .padding()
                    Text("Execution Completed")
                }
            } else {
                Text("Unknown Error Occurred")
                    .onAppear {
                        #if DEBUG
                            fatalError()
                        #endif
                    }
            }
        }
    }

    func updateProgress() {
        currentProgress = Double(exactly: context.safeAccessCompletedMachines.count) ?? 0
        totalProgress = Double(exactly: context.machines.count) ?? 0
        let completed = context.safeAccessCompletedMachines
        inProgressName = context.machines
            .filter { !completed.contains($0) }
            .compactMap { context.names[$0] }
        completedName = completed
            .compactMap { context.names[$0] }
    }
}
