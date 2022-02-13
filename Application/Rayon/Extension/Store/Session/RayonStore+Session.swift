//
//  RayonStore+Session.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/3/1.
//

import Foundation
import NSRemoteShell
import RayonModule

public extension RayonStore {
    func beginTemporarySessionStartup(
        for command: SSHCommandReader,
        requestIdentityFromBackgroundThread: @escaping () -> (RDIdentity.ID?),
        saveSessionOverrideControl: Bool = true,
        completionMainActor: ((RDSession.ID) -> Void)? = nil
    ) {
        globalProgressCount += 1
        DispatchQueue.global().async {
            defer {
                // we no longer handle this flag later
                mainActor { self.globalProgressCount -= 1 }
            }
            debugPrint("begin temporary session startup \(command.command)")
            guard command.remoteAddress.count > 0,
                  command.remotePort.count > 0,
                  let intPort = Int(command.remotePort)
            else {
                assertionFailure("invalid session info <machine info>")
                return
            }

            func createRemote() -> NSRemoteShell {
                NSRemoteShell()
                    .setupConnectionHost(command.remoteAddress)
                    .setupConnectionPort(NSNumber(value: intPort))
                    .setupConnectionTimeout(6)
                    .requestConnectAndWait()
            }
            var remote = createRemote()
            guard remote.isConnected else {
                RayonStore.presentError("Unable to connect this machine, please check your network")
                return
            }

            var finalID: RDIdentity?

            var previousUsername: String?
            let search = self.identityGroupForAutoAuth
                .filter { $0.username == command.username }
            for identity in search {
                if let prevName = previousUsername, prevName != identity.username {
                    remote = createRemote()
                }
                previousUsername = identity.username
                identity.callAuthenticationWith(remote: remote)
                if remote.isAuthenicated {
                    finalID = identity
                    break
                }
            }

            var readRequest: RDIdentity.ID?
            if !remote.isAuthenicated {
                // release any possible username for auth
                let sem = DispatchSemaphore(value: 0)
                DispatchQueue.global().async {
                    defer { sem.signal() }
                    // now, release any sheet from our-end
                    mainActor {
                        self.globalProgressInPresent = false
                    }
                    readRequest = requestIdentityFromBackgroundThread()
                }
                sem.wait()
                mainActor {
                    self.globalProgressInPresent = true
                }

                guard let request = readRequest else {
                    RayonStore.presentError("Authentication is required for session startup")
                    return
                }
                let obtainRequest = self.identityGroup[request]
                guard obtainRequest.username.count > 0 else {
                    // this should be our error, check code instead
                    return
                }
                obtainRequest.callAuthenticationWith(remote: remote)

                finalID = obtainRequest
            }

            guard remote.isAuthenicated else {
                RayonStore.presentError("Failed to authenticate this session")
                return
            }

            guard let finalIdentity = finalID else {
                return
            }

            if self.saveTemporarySession,
               // dont save a session that alreay exists
               self.findSimilarMachine(
                   withAddr: command.remoteAddress,
                   withPort: command.remotePort,
                   withUsername: command.username
               ) == nil
            {
                let machine = self.registerServer(
                    withAddress: command.remoteAddress,
                    withPort: command.remotePort,
                    withIdentity: finalIdentity.id,
                    session: remote
                )
                let session = RDSession(
                    isTemporary: true,
                    remoteMachine: machine,
                    remoteIdentity: finalIdentity,
                    representedSession: remote
                )
                if saveSessionOverrideControl {
                    self.storeRecentIfNeeded(from: machine.id)
                }
                mainActor {
                    RDSessionManager.shared.remoteSessions.append(session)
                    completionMainActor?(session.id)
                }
            } else {
                let machine = RDMachine(
                    remoteAddress: command.remoteAddress,
                    remotePort: command.remotePort,
                    name: command.remoteAddress,
                    group: "",
                    lastConnection: Date(),
                    lastBanner: remote.remoteBanner ?? "",
                    comment: remote.resolvedRemoteIpAddress ?? "",
                    associatedIdentity: finalIdentity.id.uuidString
                )
                let session = RDSession(
                    isTemporary: true,
                    remoteMachine: machine,
                    remoteIdentity: finalIdentity,
                    representedSession: remote
                )
                if saveSessionOverrideControl {
                    self.storeRecentIfNeeded(from: command)
                }
                mainActor {
                    RDSessionManager.shared.remoteSessions.append(session)
                    completionMainActor?(session.id)
                }
            }
        }
    }

    func beginSessionStartup(
        for machine: RDMachine.ID,
        completionMainActor: ((RDSession.ID) -> Void)? = nil
    ) {
        globalProgressCount += 1
        DispatchQueue.global().async {
            defer {
                // we no longer handle this flag later
                mainActor { self.globalProgressCount -= 1 }
            }
            debugPrint("begin session startup \(machine)")
            let machine = self.machineGroup[machine]
            guard machine.remoteAddress.count > 0,
                  machine.remotePort.count > 0,
                  let intPort = Int(machine.remotePort)
            else {
                RayonStore.presentError("unknown error: invalid session info")
                return
            }
            guard let rawIdentity = machine.associatedIdentity,
                  let compileIdentity = UUID(uuidString: rawIdentity)
            else {
                RayonStore.presentError("unknown error: invalid session identity")
                return
            }
            let identity = self.identityGroup[compileIdentity]
            guard identity.username.count > 0 else {
                RayonStore.presentError("unknown error: invalid session identity")
                return
            }
            let remote = NSRemoteShell()
                .setupConnectionHost(machine.remoteAddress)
                .setupConnectionPort(NSNumber(value: intPort))
                .setupConnectionTimeout(6)
                .requestConnectAndWait()
            guard remote.isConnected else {
                RayonStore.presentError("Unable to connect this machine, please check your network")
                return
            }
            identity.callAuthenticationWith(remote: remote)
            guard remote.isAuthenicated else {
                RayonStore.presentError("Unable to authenticate session, please check your identity setting")
                return
            }
            let session = RDSession(
                isTemporary: false,
                remoteMachine: machine,
                remoteIdentity: identity,
                representedSession: remote
            )
            self.storeRecentIfNeeded(from: machine.id)
            mainActor {
                RDSessionManager.shared.remoteSessions.append(session)
                completionMainActor?(session.id)
            }
        }
    }

    func removeSessionFromStorage(with session: RDSession.ID) {
        for (index, lookup) in RDSessionManager.shared.remoteSessions.enumerated() {
            if lookup.id == session {
                let context = lookup.context
                let shell = context.shell
                DispatchQueue.global().async {
                    debugPrint("[request disconnect] \(shell.remoteHost):\(shell.remotePort)")
                    shell.requestDisconnectAndWait()
                    debugPrint("[request disconnect] done at \(shell.remoteHost):\(shell.remotePort)")
                    context.makeARCGreateAgain()
                }
                RDSessionManager.shared.remoteSessions.remove(at: index)
                return
            }
        }
    }
}
