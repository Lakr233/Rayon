//
//  FileTransferManager.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/18.
//

import Foundation

import RayonModule
import SwiftUI

class FileTransferManager: ObservableObject {
    static let shared = FileTransferManager()

    private init() {}

    @Published var transfers: [FileTransferContext] = []

    func begin(for machineId: RDMachine.ID, force: Bool = false) {
        assert(Thread.isMainThread, "accessing to property terminals requires main thread")
        debugPrint("\(self) \(#function) \(machineId)")
        if !force {
            for transfer in transfers where transfer.machine.id == machineId {
                UIBridge.requiresConfirmation(
                    message: "Another file transfer for this machine is already running"
                ) { confirmed in
                    guard confirmed else {
                        return
                    }
                    self.begin(for: machineId, force: true)
                }
                return
            }
        }
        let machine = RayonStore.shared.machineGroup[machineId]
        guard machine.isNotPlaceholder() else {
            UIBridge.presentError(with: "Unknown Bad Data")
            return
        }
        var get: RDIdentity?
        if let sid = machine.associatedIdentity,
           let uid = UUID(uuidString: sid),
           RayonStore.shared.identityGroup[uid].username.count > 0
        {
            get = RayonStore.shared.identityGroup[uid]
        }
        let object = FileTransferContext(machine: machine, identity: get)
        transfers.append(object)
    }

    func end(for contextId: UUID) {
        mainActor { [self] in
            debugPrint("\(self) \(#function) \(contextId)")
            let index = transfers.firstIndex { $0.id == contextId }
            guard let index = index else { return }
            let sftp = transfers.remove(at: index)
            sftp.processShutdown()
            sftp.destroyedSession = true
        }
    }
}
