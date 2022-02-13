//
//  RDSession.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import NSRemoteShell
import SwiftUI
import XTerminalUI

struct RDSession: Identifiable {
    init(
        id: UUID = UUID(),
        isTemporary: Bool,
        remoteMachine: RDRemoteMachine,
        remoteIdentity: RDIdentity,
        representedSession: NSRemoteShell
    ) {
        self.id = id
        context = .init(
            sessionID: id,
            shell: representedSession,
            isTemporary: isTemporary,
            remoteMachine: remoteMachine,
            remoteIdentity: remoteIdentity
        )
    }

    var id = UUID()

    let context: RDSessionAssoicatedContext
}

class RDSessionAssoicatedContext: ObservableObject {
    var shell: NSRemoteShell

    let sessionID: RDSession.ID

    var isTemporary: Bool
    var remoteMachine: RDRemoteMachine
    var remoteIdentity: RDIdentity

    init(
        sessionID: RDSession.ID,
        shell: NSRemoteShell,
        isTemporary: Bool,
        remoteMachine: RDRemoteMachine,
        remoteIdentity: RDIdentity
    ) {
        self.sessionID = sessionID
        self.shell = shell
        self.isTemporary = isTemporary
        self.remoteMachine = remoteMachine
        self.remoteIdentity = remoteIdentity

        createSession()
    }

    class TerminalSessionInfo: Identifiable, ObservableObject, Equatable, Hashable {
        let id: UUID = .init()
        @Published var title: String = ""

        static func == (
            lhs: RDSessionAssoicatedContext.TerminalSessionInfo,
            rhs: RDSessionAssoicatedContext.TerminalSessionInfo
        ) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    func nobodyCanSaveArc() {
        // **** you
        shell = NSRemoteShell()
    }

    // the terminal channel will actually being create when view doing load
    @Published var terminalSessions: [UUID] = []
    var terminalSessionInfos: [UUID: TerminalSessionInfo] = [:]

    func adjust(title: String, for session: UUID) {
        var title = title
        if title.contains(": ") {
            title = title.components(separatedBy: ": ").last ?? title
        }
        terminalSessionInfos[session]?.title = title
    }

    func createSession() {
        let session = TerminalSessionInfo()
        terminalSessionInfos[session.id] = session
        terminalSessions.append(session.id)
    }

    func terminalChannelAlive(for terminalSession: UUID) -> Bool {
        !TerminalManager
            .shared
            // actually ok, if call chain not set, will not really open it
            .terminalSession(for: terminalSession)
            .completed
    }

    func terminateTermSession(for terminalSession: UUID) {
        TerminalManager
            .shared
            .terminalSession(for: terminalSession)
            .stop = true
        terminalSessions.removeAll { $0 == terminalSession }
        terminalSessionInfos.removeValue(forKey: terminalSession)
    }
}

class TerminalManager {
    public static let shared = TerminalManager()
    private init() {}

    class CoreSession: Identifiable {
        let id: UUID
        init(id: UUID) {
            self.id = id
        }

        let coreUI = STerminalView()
        let lock = NSLock()
        var setupComplete: Bool = false
        var completed: Bool = false
        var title: String = ""
        var withTermianlSize: (() -> CGSize)?
        var withWriteData: (() -> String)?
        var withOutput: ((String) -> Void)?
        var withContinuationHandler: (() -> Bool)?
        var stop: Bool = false

        func startIfNeeded(with shell: NSRemoteShell) {
            lock.lock()
            defer {
                lock.unlock()
            }
            guard !setupComplete else {
                return
            }
            setupComplete = true
            debugPrint("processing channel startup")
            DispatchQueue.global().async { [weak self, weak shell] in
                let canOpen = self?.withContinuationHandler?() ?? false
                guard canOpen else {
                    debugPrint("refusing channel startup due to broken data flow")
                    return
                }
                // ****! ARC ****!
                shell?.open(withTerminal: "xterm") { [weak self] in
                    self?.withTermianlSize?() ?? CGSize(width: 50, height: 20)
                } withWriteData: { [weak self] in
                    self?.withWriteData?() ?? ""
                } withOutput: { [weak self] output in
                    self?.withOutput?(output)
                } withContinuationHandler: { [weak self] in
                    // closed
                    if self?.stop ?? true { return false }
                    // ask the view for state
                    return self?.withContinuationHandler?() ?? false
                }
                self?.coreUI.write("\r\n[*] Channel Connection Closed\r\n")
                // ARC Hurry: shell object at 0x6000039195e0 deallocating
                self?.completed = true
                self?.coreUI
                    .setupBufferChain(callback: nil)
                    .setupTitleChain(callback: nil)
                    .setupBellChain(callback: nil)
                self?.withTermianlSize = nil
                self?.withWriteData = nil
                self?.withOutput = nil
                self?.withContinuationHandler = nil
            }
        }

        func rebindChain(
            termianlSize: (() -> CGSize)?,
            writeData: (() -> String)?,
            output: ((String) -> Void)?,
            continuationHandler: (() -> Bool)?
        ) {
            withTermianlSize = termianlSize
            withWriteData = writeData
            withOutput = output
            withContinuationHandler = continuationHandler
        }

//        let data: String // ? not required ? since we hold ref to coreUI
    }

    private var sessionStorage: [CoreSession] = []

    func terminalSession(for token: UUID) -> CoreSession {
        for session in sessionStorage where session.id == token {
            return session
        }
        let create = CoreSession(id: token)
        sessionStorage.append(create)
        return create
    }

    // no need to destroy the terminal session(aka libssh2 channel)
    // when the session(aka libssh2 session) destroy
    // connection will close then release any object
}
