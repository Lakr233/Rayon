//
//  SnippetExecuteView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/4.
//

import NSRemoteShell
import RayonModule
import SwiftUI
import XTerminalUI

struct SnippetExecuteView: View {
    @StateObject var context: SnippetExecuteContext
    @Environment(\.presentationMode) var presentationMode

    @State var widthInstructor: CGSize = .init()

    var terminalWidth: CGFloat {
        if context.machineGroup.count == 1 {
            return CGFloat(widthInstructor.width)
        }
        if widthInstructor.width < 300 {
            return 250
        }
        if widthInstructor.width > 500 {
            return 500
        }
        return CGFloat(widthInstructor.width)
    }

    var body: some View {
        Group {
            if context.interfaceAllocated {
                contentView
            } else {
                ProgressView().expended()
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
        .onAppear {
            guard !context.interfaceAllocated else {
                return
            }
            context.beginBootstrap()
        }
        .navigationTitle("Snippet - " + context.snippet.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                if context.running.isEmpty {
                    presentationMode.wrappedValue.dismiss()
                    return
                } else {
                    UIBridge.requiresConfirmation(
                        message: "Process in progress, terminate them all?"
                    ) { yes in
                        if yes {
                            for machine in context.machineGroup {
                                context.close(for: machine.id)
                            }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            } label: {
                Label("Terminate", systemImage: "xmark")
            }
        }
    }

    var contentView: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            GeometryReader { r in
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(0 ..< context.machineGroup.count, id: \.self) { idx in
                            makeView(for: idx)
                        }
                    }
                }
                .onChange(of: r.size) { newValue in
                    widthInstructor = newValue
                }
            }
            .expended()
        }
    }

    var header: some View {
        Group {
            VStack(alignment: .leading, spacing: 5) {
                if context.running.isEmpty {
                    Image(
                        systemName: context.hasError
                            ? "checkmark.circle.trianglebadge.exclamationmark" : "checkmark.circle.fill"
                    )
                    .foregroundColor(
                        context.hasError
                            ? .orange : .green
                    )
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                } else {
                    runningItems
                }
                ProgressView(
                    context.running.isEmpty ? "Execution Complete" : "Execution In Progress",
                    value: context.completedProgress,
                    total: context.totalProgress
                )
                .animation(.interactiveSpring(), value: context.completedProgress)
                .font(.system(.headline, design: .rounded))
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.interactiveSpring(), value: context.running)
        .padding()
        .background(
            Color(UIColor.systemGray6)
                .cornerRadius(8)
        )
    }

    var runningItems: some View {
        HStack(spacing: 2) {
            Image(systemName: "play.fill")
            Spacer()
                .frame(width: 2, height: 0)
            ScrollView(.horizontal) {
                HStack(spacing: 2) {
                    ForEach(context.running) { machine in
                        Text(machine.name)
                            .padding(4)
                            .background(
                                Color.accentColor
                                    .opacity(0.1)
                                    .cornerRadius(4)
                            )
                            .padding(4)
                    }
                }
            }
            Text("\(context.running.count)")
        }
        .animation(.interactiveSpring(), value: context.running)
        .font(.system(.subheadline, design: .rounded))
    }

    func makeView(for idx: Int) -> some View {
        VStack(alignment: .center, spacing: 8) {
            HStack {
                Label(context.machineGroup[idx].name, systemImage: "arrow.right")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button {
                    context.close(for: context.machineGroup[idx].id)
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.red)
                }
                .disabled(context.completed.contains(context.machineGroup[idx]))
            }
            Divider()
            context.terminalGroup[idx]
        }
        .expended()
        .padding(12)
        .background(
            Color(UIColor.systemGray6)
                .cornerRadius(8)
        )
        .frame(width: terminalWidth)
    }
}
