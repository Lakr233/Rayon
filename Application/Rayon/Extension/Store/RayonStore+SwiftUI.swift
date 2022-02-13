//
//  RayonStore+SwiftUI.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/3/1.
//

import RayonModule
import SwiftUI

extension RayonStore {
    func createNewWindowGroup<T: View>(for view: T) -> Window {
        UIBridge.openNewWindow(from: view)
    }

    func beginBatchScriptExecution(for snippet: RDSnippet.ID, and machines: [RDMachine.ID]) {
        let snippet = snippetGroup[snippet]
        guard snippet.code.count > 0 else {
            return
        }
        guard machines.count > 0 else {
            RayonStore.presentError("No machine was selected for execution")
            return
        }
        let view = BatchSnippetExecView(snippet: snippet, machines: machines)
        UIBridge.openNewWindow(from: view)
    }
}
