//
//  Generic.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/11.
//

import Foundation
import RayonModule
import SwiftUI

enum RayonUtil {
    static func selectIdentity() -> RDIdentity.ID? {
        assert(!Thread.isMainThread, "select identity must be called from background thread")

        var selection: RDIdentity.ID?
        let sem = DispatchSemaphore(value: 0)

        debugPrint("Picking Identity")

        mainActor {
            var panelRef: NSPanel?
            let controller = NSHostingController(rootView: Group {
                IdentityPickerSheetView {
                    selection = $0
                    if let panel = panelRef { panel.close() }
                    sem.signal()
                }
                .environmentObject(RayonStore.shared)
                .frame(width: 700, height: 400)
            })
            let panel = NSPanel(contentViewController: controller)
            panelRef = panel
            panel.title = ""
            panel.titleVisibility = .hidden

            if let keyWindow = NSApp.keyWindow {
                keyWindow.beginSheet(panel) { _ in }
            } else {
                panel.makeKeyAndOrderFront(nil)
            }
        }
        sem.wait()
        return selection
    }
}
