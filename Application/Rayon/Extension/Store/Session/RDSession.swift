//
//  RDSession.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import Foundation
import NSRemoteShell
import RayonModule

class RDSessionManager: ObservableObject {
    static let shared: RDSessionManager = .init()

    private init() {}

    @Published public var remoteSessions: [RDSession] = []
}

public struct RDSession: Identifiable {
    public init(
        id: UUID = UUID(),
        isTemporary: Bool,
        remoteMachine: RDMachine,
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

    public var id = UUID()

    public let context: RDSession.Context
}
