//
//  RDPortForward.swift
//
//
//  Created by Lakr Aream on 2022/3/10.
//

import Foundation
import NSRemoteShell

public struct RDPortForward: Codable, Identifiable, Equatable {
    public init(
        id: UUID = .init(),
        name: String = "",
        forwardOrientation: ForwardOrientation = .listenLocal,
        bindPort: Int = 0,
        targetHost: String = "",
        targetPort: Int = 0,
        usingMachine: RDMachine.ID? = nil,
        attachment: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.forwardOrientation = forwardOrientation
        self.bindPort = bindPort
        self.targetHost = targetHost
        self.targetPort = targetPort
        self.usingMachine = usingMachine
        self.attachment = attachment
    }

    public var id: UUID

    public var name: String

    public enum ForwardOrientation: String, Codable {
        case listenLocal
        case listenRemote
    }

    public var forwardOrientation: ForwardOrientation = .listenLocal

    public var bindPort: Int // UInt32 maybe?

    public var targetHost: String
    public var targetPort: Int // UInt32 maybe?

    public var usingMachine: RDMachine.ID?

    public var attachment: [String: String]

    func isValid() -> Bool {
        guard bindPort >= 0, bindPort <= 65535,
              !targetHost.isEmpty,
              targetPort >= 0, targetPort <= 65535,
              let machine = usingMachine,
              RayonStore.shared.machineGroup[machine].isNotPlaceholder()
        else {
            return false
        }
        return true
    }
}
