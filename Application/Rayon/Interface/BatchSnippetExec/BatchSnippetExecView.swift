//
//  BatchSnippetExecView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/13.
//

import NSRemoteShell
import SwiftUI

struct BatchSnippetExecView: View {
    internal init(snippet: RDSnippet, machines: [RDRemoteMachine.ID]) {
        self.snippet = snippet
        self.machines = machines
        _context = .init(wrappedValue: .init(snippet: snippet, machines: machines))
    }

    let snippet: RDSnippet
    let machines: [RDRemoteMachine.ID]

    @StateObject
    var windowObserver: WindowObserver = .init()

    @StateObject var store: RayonStore = .shared

    @StateObject var context: BatchSnippetExecContext

    var body: some View {
        builder
            .environmentObject(store)
            .environmentObject(context)
    }

    var builder: some View {
        NavigationView {
            BatchSnippetSidebarView()
            BatchExecMainView()
        }
        .background(
            HostingWindowFinder { [weak windowObserver] window in
                windowObserver?.window = window
                setWindowTitle()
            }
        )
        .onAppear {
            setWindowTitle()
        }
        .requiresFrame()
    }

    func setWindowTitle() {
        windowObserver.window?.title = "Batch Execution: \(snippet.name)"
        windowObserver.window?.subtitle = "\(machines.count) target in queue"
    }
}
