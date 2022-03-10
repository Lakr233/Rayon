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
    static func findWindow() -> NSWindow? {
        if let key = NSApp.keyWindow {
            return key
        }
        for window in NSApp.windows where window.isVisible {
            return window
        }
        return nil
    }

    static func selectIdentity() -> RDIdentity.ID? {
        assert(!Thread.isMainThread, "select identity must be called from background thread")

        var selection: RDIdentity.ID?
        let sem = DispatchSemaphore(value: 0)

        debugPrint("Picking Identity")

        mainActor {
            var panelRef: NSPanel?
            var windowRef: NSWindow?
            let controller = NSHostingController(rootView: Group {
                IdentityPickerSheetView {
                    selection = $0
                    if let panel = panelRef {
                        if let windowRef = windowRef {
                            windowRef.endSheet(panel)
                        } else {
                            panel.close()
                        }
                    }
                    sem.signal()
                }
                .environmentObject(RayonStore.shared)
                .frame(width: 700, height: 400)
            })
            let panel = NSPanel(contentViewController: controller)
            panelRef = panel
            panel.title = ""
            panel.titleVisibility = .hidden

            if let keyWindow = findWindow() {
                windowRef = keyWindow
                keyWindow.beginSheet(panel) { _ in }
            } else {
                sem.signal()
            }
        }
        sem.wait()
        return selection
    }

    static func selectMachine(allowMany: Bool = true) -> [RDMachine.ID] {
        assert(!Thread.isMainThread, "select identity must be called from background thread")

        var selection = [RDMachine.ID]()
        let sem = DispatchSemaphore(value: 0)

        debugPrint("Picking Machine")

        mainActor {
            var panelRef: NSPanel?
            var windowRef: NSWindow?
            let controller = NSHostingController(rootView: Group {
                MachinePickerView(onComplete: {
                    selection = $0
                    if let panel = panelRef {
                        if let windowRef = windowRef {
                            windowRef.endSheet(panel)
                        } else {
                            panel.close()
                        }
                    }
                    sem.signal()
                }, allowSelectMany: allowMany)
                    .environmentObject(RayonStore.shared)
                    .frame(width: 700, height: 400)
            })
            let panel = NSPanel(contentViewController: controller)
            panelRef = panel
            panel.title = ""
            panel.titleVisibility = .hidden

            if let keyWindow = findWindow() {
                windowRef = keyWindow
                keyWindow.beginSheet(panel) { _ in }
            } else {
                sem.signal()
            }
        }
        sem.wait()
        return selection
    }

    static func selectOneMachine() -> RDMachine.ID? {
        selectMachine(allowMany: false).first
    }
}
