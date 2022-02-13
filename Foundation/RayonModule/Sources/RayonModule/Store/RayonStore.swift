//
//  RayonStore.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/8.
//

import NSRemoteShell
import PropertyWrapper

public class RayonStore: ObservableObject {
    public init() {
        defer {
            debugPrint("RayonStore initialer completed")
        }

        licenseAgreed = UserDefaults
            .standard
            .value(
                forKey: UserDefaultKey.licenseAgreed.rawValue
            ) as? Bool ?? false
        storeRecent = UDStoreRecent
        saveTemporarySession = UDSaveTemporarySession

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
            from: .timeout,
            timeout.self
        ) {
            timeout = read
        }
        if timeout <= 0 { timeout = 5 }
        if let read = readEncryptedDefault(
            from: .openInterfaceAutomatically,
            openInterfaceAutomatically.self
        ) {
            openInterfaceAutomatically = read
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

    @Published public var timeout: Int = 0 {
        didSet {
            storeEncryptedDefault(
                to: .timeout,
                with: timeout
            )
        }
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
}
