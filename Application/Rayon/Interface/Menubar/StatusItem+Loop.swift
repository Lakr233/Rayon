//
//  StatusItem+Loop.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/3/1.
//

import AppKit
import NSRemoteShell
import RayonModule
import SwiftUI

extension MenubarStatusItem {
    func beginFrameLoop() {
        let thread = Thread { [weak self] in
            while self?.loopContinue ?? false {
                usleep(100)
                guard let self = self else {
                    return
                }
                self.switchNextFrame()
                self.accessLock.lock()
                let interval = self.catSpeed.rawValue
                self.accessLock.unlock()
                var sleepInterval = (UInt32(exactly: interval * 1_000_000) ?? 1_000_000)
                if sleepInterval < 1000 { sleepInterval = 1000 }
                usleep(sleepInterval)
            }
            debugPrint("\(#function) end")
        }
        thread.start()
    }

    func beginShellLoop() {
        let thread = Thread { [weak self] in
            while self?.loopContinue ?? false {
                usleep(100)
                guard let self = self else {
                    return
                }
                self.updateServerStatusInfo()
            }
            debugPrint("\(#function) end")
        }
        thread.start()
    }

    func switchNextFrame() {
        guard accessLock.try() else {
            return
        }
        defer { accessLock.unlock() }

        guard !frames.isEmpty else {
            return
        }
        let interval = catSpeed.rawValue
        if interval <= 0 {
            mainActor { [self] in
                statusItem.button?.image = NSImage(named: "cat_frame_crash")
            }
            return
        }
        defer { currentImageIndex += 1 }
        if currentImageIndex > frames.count - 1 {
            currentImageIndex = 0
        }
        let image = frames[currentImageIndex]
        mainActor { [self] in
            statusItem.button?.image = image

            // check if already deleted
            let check = RayonStore.shared.machineGroup[machine.id]
            guard check.isNotPlaceholder() else {
                closeThisItem()
                return
            }
        }
    }

    func updateServerStatusInfo() {
        catSpeed = .broken
        let shell = NSRemoteShell()
            .setupConnectionHost(machine.remoteAddress)
            .setupConnectionPort(NSNumber(value: Int(machine.remotePort) ?? 0))
            .setupConnectionTimeout(RayonStore.shared.timeoutNumber)
        shell.requestConnectAndWait()
        representedShell = shell
        identity.callAuthenticationWith(remote: shell)
        while loopContinue, shell.isConnected, shell.isAuthenicated {
            statusInfo.requestInfoAndWait(with: shell)
            let cpuPercent = statusInfo.processor.summary.sumUsed
            var newSpeed = CatSpeed.broken
            if false {
            } else if cpuPercent < 5 {
                newSpeed = .hang
            } else if cpuPercent < 20 {
                newSpeed = .walk
            } else if cpuPercent < 50 {
                newSpeed = .run
            } else if cpuPercent < 80 {
                newSpeed = .fast
            } else {
                newSpeed = .light
            }
            if newSpeed != catSpeed {
                print("switching cat speed to \(newSpeed.rawValue)")
                accessLock.lock()
                catSpeed = newSpeed
                accessLock.unlock()
            }
            sleep(UInt32(exactly: RayonStore.shared.monitorInterval) ?? 5)
        }
        catSpeed = .broken
        sleep(5)
    }
}
