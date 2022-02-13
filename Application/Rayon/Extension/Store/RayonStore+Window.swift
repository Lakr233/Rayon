//
//  RayonStore+Window.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/3/1.
//

import Foundation
import RayonModule

private var remoteSessionWindows: [UUID: Window] = [:]

extension RayonStore {
    func storeSessionWindow(with window: Window, and session: RDSession.ID) {
        // if value already exists, close the window
        if let window = remoteSessionWindows[session] {
            // this is our error, not cleaning pickup or some thing like that
            // this will happen if we are opening the interface for 0.5 sec delay
            // but user was being single for too long and so called speedy boy
            debugPrint("window being linked to session over placed another")
            if let window = window as? NSCloseProtectedWindow {
                window.forceClose = true
            }
            window.close()
        }
        remoteSessionWindows[session] = window
    }

    func terminateSession(with session: RDSession.ID) {
        if let window = remoteSessionWindows[session] {
            if let window = window as? NSCloseProtectedWindow {
                window.forceClose = true
            }
            window.close()
            remoteSessionWindows.removeValue(forKey: session)
        }
        removeSessionFromStorage(with: session)
    }

    func requestSessionInterface(session: RDSession.ID) {
        // lookup if any window is available before create new
        if let window = remoteSessionWindows[session] {
            window.makeKeyAndOrderFront(nil)
            return
        }
        for target in RDSessionManager.shared.remoteSessions where target.id == session {
            let window = createNewWindowGroup(for: SessionView(session: target))
            storeSessionWindow(with: window, and: session)
            window.title = "Rayon Session"
            window.subtitle = "\(target.context.identity.username)@\(target.context.machine.remoteAddress)"
            return
        }
        RayonStore.presentError("Unable to request session interface, invalid or malformed session data was found")
    }
}
