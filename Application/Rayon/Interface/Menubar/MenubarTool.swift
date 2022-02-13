//
//  MenubarTool.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/3/1.
//

import AppKit
// import AuxiliaryExecute
import RayonModule

// private let dataEncoder = JSONEncoder()
// private let dataDecoder = JSONDecoder()

class MenubarTool {
//    let menubarMagic = "wiki.qaq.menubar"
//    var menubarInitialCommand: MenubarTool.ArgumentCompiler!
//    let mebubarLoaderQueue = DispatchQueue(label: "wiki.qaq.menubar.loader", attributes: .concurrent)
    let bootstrapLock = NSLock()
//    var menubarAppPids = [pid_t]()

    static let shared = MenubarTool()

    var statusItem: [MenubarStatusItem] = []
    var hasCat: Bool {
        bootstrapLock.lock()
        let ret = !statusItem.isEmpty
        bootstrapLock.unlock()
        return ret
    }

    private init() {}

    struct ArgumentCompiler: Codable {
        let machine: RDMachine.ID
        let identity: RDIdentity.ID

        init(machine: RDMachine.ID, identity: RDIdentity.ID) {
            self.machine = machine
            self.identity = identity
        }

//        func commandLineArgument() -> String? {
//            if let data = try? dataEncoder.encode(self) {
//                return data.base64EncodedString()
//            }
//            return nil
//        }

        func createStatusItem() -> MenubarStatusItem {
            let machine = RayonStore.shared.machineGroup[machine]
            let identity = RayonStore.shared.identityGroup[identity]
            guard machine.isNotPlaceholder(), !identity.username.isEmpty else {
                fatalError("Failed to load machine info for menubar creation")
            }
            return .init(machine: machine, identity: identity)
        }
    }

//    func requireMenubarSetup() -> Bool {
//        guard CommandLine.arguments.count >= 3,
//              CommandLine.arguments[1] == menubarMagic,
//              let data = Data(base64Encoded: CommandLine.arguments[2]),
//              let compiler = try? dataDecoder.decode(ArgumentCompiler.self, from: data)
//        else {
//            return false
//        }
//        menubarInitialCommand = compiler
//        return true
//    }

    func createRuncat(for machineId: RDMachine.ID) {
        bootstrapLock.lock()
        let copy = statusItem
        bootstrapLock.unlock()
        for item in copy where item.machine.id == machineId {
            UIBridge.presentError(
                with: "Another cat is running for this machine",
                delay: 0
            )
            return
        }

        let machine = RayonStore.shared.machineGroup[machineId]
        guard machine.isNotPlaceholder() else {
            UIBridge.presentError(
                with: "Could not create menubar app: malformed machine info",
                delay: 0
            )
            return
        }
        guard let identityIdStr = machine.associatedIdentity,
              let identityId = UUID(uuidString: identityIdStr)
        else {
            UIBridge.presentError(
                with: "Could not create menubar app: login identity of this machine must be set",
                delay: 0
            )
            return
        }
        let identity = RayonStore.shared.identityGroup[identityId]
        guard !identity.username.isEmpty else {
            UIBridge.presentError(
                with: "Could not create menubar app: malformed identity info",
                delay: 0
            )
            return
        }
//        guard let executable = Bundle.main.executablePath else {
//            UIBridge.presentError(
//                with: "Could not locate bundle, did you move the app?"
//            )
//            return
//        }
        let compiler = ArgumentCompiler(machine: machine.id, identity: identity.id)
//        guard let parser = compiler.commandLineArgument() else {
//            UIBridge.presentError(
//                with: "Could not build command line argument"
//            )
//            return
//        }
        let item = compiler.createStatusItem()
        bootstrapLock.lock()
        statusItem.append(item)
        bootstrapLock.unlock()

        // bye bye this thread~
        // SANDBOX SUCKS
//        mebubarLoaderQueue.async {
//            var thisPid: pid_t?
//            let recipe = AuxiliaryExecute.spawn(
//                command: executable,
//                args: [self.menubarMagic, parser],
//                setPid: { pid in
//                    thisPid = pid
//                    self.bootstrapLock.lock()
//                    self.menubarAppPids.append(pid)
//                    self.bootstrapLock.unlock()
//                }
//            )
//            print("Menubar app returned: \(recipe.exitCode)")
//            self.bootstrapLock.lock()
//            self.menubarAppPids = self.menubarAppPids
//                .filter { $0 != thisPid }
//            self.bootstrapLock.unlock()
//        }
    }

//    func beginMenubarBootstrap() {
//        mainActor(delay: 0.5) {
//            NSApp.setActivationPolicy(.accessory)
//            for window in NSApp.windows {
//                window.close()
//            }
//            self.statusItem = self.menubarInitialCommand.createStatusItem()
//        }
//    }

    func remove(menubarItem: MenubarStatusItem.ID) {
        bootstrapLock.lock()
        statusItem = statusItem
            .filter { $0.id != menubarItem }
        bootstrapLock.unlock()
    }
}
