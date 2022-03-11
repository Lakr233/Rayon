//
//  RayonStore.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/8.
//

import Combine
import Foundation
import NSRemoteShell
import PropertyWrapper

public class RayonStore: ObservableObject {
    public init() {
        defer {
            debugPrint("RayonStore init completed")
        }

        licenseAgreed = UserDefaults
            .standard
            .value(
                forKey: UserDefaultKey.licenseAgreed.rawValue
            ) as? Bool ?? false
        storeRecent = UDStoreRecent
        saveTemporarySession = UDSaveTemporarySession
        timeout = UDTimeout
        reducedViewEffects = UDReducedViewEffects
        disableConformation = UDDisableConformation
        monitorInterval = UDMonitorInterval
        if timeout <= 0 { timeout = 5 }

        if let read = readEncryptedDefault(
            from: .identityGroupEncrypted,
            identityGroup.self
        ) {
            identityGroup = read
        }
        if let read = readEncryptedDefault(
            from: .machineGroupEncrypted,
            machineGroup.self
        ) {
            machineGroup = read
        }
        if let read = readEncryptedDefault(
            from: .machineRedacted,
            machineRedacted.self
        ) {
            machineRedacted = read
        }
        if let read = readEncryptedDefault(
            from: .snippetGroupEncrypted,
            snippetGroup.self
        ) {
            snippetGroup = read
        }
        if let read = readEncryptedDefault(
            from: .recentRecordEncrypted,
            recentRecord.self
        ) {
            recentRecord = read
        }
        if let read = readEncryptedDefault(
            from: .openInterfaceAutomatically,
            openInterfaceAutomatically.self
        ) {
            openInterfaceAutomatically = read
        }
        if let read = readEncryptedDefault(
            from: .portForwardEncrypted,
            portForwardGroup.self
        ) {
            portForwardGroup = read
        }
    }

    public static let shared = RayonStore()

    @Published public var licenseAgreed: Bool = false {
        didSet {
            storeDefault(to: .licenseAgreed, with: licenseAgreed)
        }
    }

    @Published public var globalProgressInPresent: Bool = false
    public var globalProgressCount: Int = 0 {
        didSet {
            if globalProgressCount == 0 {
                globalProgressInPresent = false
            } else {
                globalProgressInPresent = true
            }
        }
    }

    @UserDefaultsWrapper(key: "wiki.qaq.rayon.timeout", defaultValue: 5)
    private var UDTimeout: Int
    @Published public var timeout: Int = 0 {
        didSet {
            UDTimeout = timeout
        }
    }

    @UserDefaultsWrapper(key: "wiki.qaq.rayon.monitorInterval", defaultValue: 3)
    private var UDMonitorInterval: Int
    @Published public var monitorInterval: Int = 0 {
        didSet {
            UDMonitorInterval = monitorInterval
        }
    }

    public var timeoutNumber: NSNumber {
        NSNumber(value: timeout)
    }

    @Published public var openInterfaceAutomatically: Bool = true {
        didSet {
            storeEncryptedDefault(
                to: .openInterfaceAutomatically,
                with: openInterfaceAutomatically
            )
        }
    }

    @Published public var identityGroup: RDIdentityGroup = .init() {
        didSet {
            storeEncryptedDefault(
                to: .identityGroupEncrypted,
                with: identityGroup
            )
        }
    }

    public var identityGroupForAutoAuth: [RDIdentity] {
        identityGroup
            .identities
            .filter(\.authenticAutomatically)
            // make sure not to reopen too many times
            .sorted { $0.username < $1.username }
    }

    @Published public var machineRedacted: RDMachine.RedactedLevel = .none {
        didSet {
            storeEncryptedDefault(
                to: .machineRedacted,
                with: machineRedacted
            )
        }
    }

    @Published public var machineGroup: RDMachineGroup = .init() {
        didSet {
            storeEncryptedDefault(
                to: .machineGroupEncrypted,
                with: machineGroup
            )
        }
    }

    @UserDefaultsWrapper(key: "wiki.qaq.rayon.saveTemporarySession", defaultValue: true)
    private var UDSaveTemporarySession: Bool

    @Published public var saveTemporarySession: Bool = false {
        didSet {
            UDSaveTemporarySession = saveTemporarySession
        }
    }

    @UserDefaultsWrapper(key: "wiki.qaq.rayon.storeRecent", defaultValue: true)
    private var UDStoreRecent: Bool

    @Published public var storeRecent: Bool = false {
        didSet {
            UDStoreRecent = storeRecent
            if !storeRecent {
                recentRecord = []
            }
        }
    }

    @UserDefaultsWrapper(key: "wiki.qaq.rayon.reducedViewEffects", defaultValue: false)
    private var UDReducedViewEffects: Bool

    @Published public var reducedViewEffects: Bool = false {
        didSet {
            UDReducedViewEffects = reducedViewEffects
        }
    }

    @UserDefaultsWrapper(key: "wiki.qaq.rayon.disableConformation", defaultValue: false)
    private var UDDisableConformation: Bool

    @Published public var disableConformation: Bool = false {
        didSet {
            UDDisableConformation = disableConformation
        }
    }

    @UserDefaultsWrapper(key: "wiki.qaq.rayon.maxRecentRecordCount", defaultValue: 8)
    public var maxRecentRecordCount: Int

    @Published public var recentRecord: [RecentConnection] = [] {
        didSet {
            storeEncryptedDefault(
                to: .recentRecordEncrypted,
                with: recentRecord
            )
        }
    }

    @Published public var snippetGroup: RDSnippetGroup = .init() {
        didSet {
            storeEncryptedDefault(
                to: .snippetGroupEncrypted,
                with: snippetGroup
            )
        }
    }

    @Published public var portForwardGroup: RDPortForwardGroup = .init() {
        didSet {
            storeEncryptedDefault(
                to: .portForwardEncrypted,
                with: portForwardGroup
            )
        }
    }
}
