//
//  Monitor.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/3.
//

import Foundation
import NSRemoteShell
import RayonModule
import SwiftUI

class MonitorManager: ObservableObject {
    static let shared = MonitorManager()

    private init() {}

    @Published var monitors: [MonitorContext] = []

    func begin(for machineId: RDMachine.ID) {
        assert(Thread.isMainThread, "access to monitors property requires main thread")
        debugPrint("\(self) \(#function) \(machineId)")
        for monitor in monitors where monitor.machine.id == machineId {
            UIBridge.presentError(with: "Another monitor is already running on this server")
            return
        }
        let machine = RayonStore.shared.machineGroup[machineId]
        guard machine.isNotPlaceholder() else {
            UIBridge.presentError(with: "Malformed application memory")
            return
        }
        guard let aid = machine.associatedIdentity,
              let uid = UUID(uuidString: aid)
        else {
            UIBridge.presentError(with: "Associated identity is required for monitoring")
            return
        }
        let identity = RayonStore.shared.identityGroup[uid]
        guard !identity.username.isEmpty else {
            UIBridge.presentError(with: "Malformed application memory")
            return
        }
        let context = MonitorContext(machine: machine, identity: identity)
        RayonStore.shared.storeRecentIfNeeded(from: machineId)

        mainActor {
            guard RayonStore.shared.openInterfaceAutomatically else { return }
            let host = UIHostingController(rootView: MonitorContext.DefaultPresent(context: context))
//            the swiftui f*** up my toolbar
//            host.isModalInPresentation = true
            host.preferredContentSize = preferredPopOverSize
            host.modalTransitionStyle = .coverVertical
            host.modalPresentationStyle = .formSheet
            UIWindow.shutUpKeyWindow?
                .topMostViewController?
                .present(next: host)
        }

        monitors.append(context)
    }

    func end(for contextId: UUID) {
        mainActor { [self] in
            debugPrint("\(self) \(#function) \(contextId)")
            let index = monitors.firstIndex { $0.id == contextId }
            guard let index = index else { return }
            let machine = monitors.remove(at: index)
            machine.processShutdown()
        }
    }
}
