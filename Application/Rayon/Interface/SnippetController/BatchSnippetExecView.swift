//
//  BatchSnippetExecView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/13.
//

import NSRemoteShell
import RayonModule
import SwiftUI

struct BatchSnippetExecView: View {
    internal init(snippet: RDSnippet, machines: [RDMachine.ID], onComplete: @escaping () -> Void) {
        self.snippet = snippet
        self.machines = machines
        self.onComplete = onComplete
        _context = .init(wrappedValue: .init(snippet: snippet, machines: machines))
    }

    let snippet: RDSnippet
    let machines: [RDMachine.ID]
    let onComplete: () -> Void

    @StateObject var store: RayonStore = .shared

    @StateObject var context: BatchSnippetExecContext

    var body: some View {
        builder
            .environmentObject(store)
            .environmentObject(context)
    }

    var builder: some View {
        SheetTemplate.makeSheet(
            title: "Batch Exec",
            body: AnyView(sheetBody)
        ) { _ in
            func doExit() {
                onComplete()
                DispatchQueue.global().async {
                    context.shellObjects
                        .values
                        .forEach { $0.requestDisconnectAndWait() }
                }
            }
            if !context.completed {
                UIBridge.requiresConfirmation(message: "Are you sure you want to quit?") { y in
                    if y { doExit() }
                }
            } else {
                doExit()
            }
        }
    }

    var sheetBody: some View {
        NavigationView {
            BatchSnippetSidebarView()
            BatchExecMainView()
        }
    }
}
