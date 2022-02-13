//
//  RDSessionContext.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/3/1.
//

import Foundation
import NSRemoteShell
import RayonModule

public extension RDSession {
    class Context: ObservableObject {
        public var shell: NSRemoteShell

        public let id: RDSession.ID

        public var isTemporary: Bool
        public var machine: RDMachine
        public var identity: RDIdentity

        public init(
            sessionID: RDSession.ID,
            shell: NSRemoteShell,
            isTemporary: Bool,
            remoteMachine: RDMachine,
            remoteIdentity: RDIdentity
        ) {
            id = sessionID
            self.shell = shell
            self.isTemporary = isTemporary
            machine = remoteMachine
            identity = remoteIdentity

            createTerminal()
        }

        public func makeARCGreateAgain() {
            shell = NSRemoteShell()
        }

        // the terminal channel will actually being create when view doing load
        @Published public var terminals: [UUID] = []
        public var terminalInfo: [UUID: TSInfo] = [:]

        public func adjustTerminal(title: String, for session: UUID) {
            var title = title
            if title.contains(": ") {
                title = title.components(separatedBy: ": ").last ?? title
            }
            terminalInfo[session]?.title = title
        }

        public func createTerminal() {
            let session = TSInfo()
            terminalInfo[session.id] = session
            terminals.append(session.id)
        }

        public func terminalChannelIsAlive(for session: UUID) -> Bool {
            !TerminalManager
                .shared
                // actually ok, if call chain not set, will not really open it
                .loadTerminal(for: session)
                .completed
        }

        public func terminateTermSession(for session: UUID) {
            TerminalManager
                .shared
                .loadTerminal(for: session)
                .stop = true
            terminals.removeAll { $0 == session }
            terminalInfo.removeValue(forKey: session)
        }
    }
}

public extension RDSession.Context {
    class TSInfo: Identifiable, ObservableObject, Equatable, Hashable {
        public let id: UUID = .init()
        @Published public var title: String = ""

        public init() {}

        public static func == (
            lhs: RDSession.Context.TSInfo,
            rhs: RDSession.Context.TSInfo
        ) -> Bool {
            lhs.id == rhs.id
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
}
