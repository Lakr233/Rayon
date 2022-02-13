//
//  RayonStore.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/8.
//

import NSRemoteShell
import PropertyWrapper
import SwiftUI

private let documentEncoder = PropertyListEncoder()
private let documentDecoder = PropertyListDecoder()

private enum UserDefaultKey: String {
    case userIdentitiesEncrypted
    case remoteMachinesEncrypted
    case userSnippetsEncrypted
    case recentRecordEncrypted
    case remoteMachineRedactedLevel
    case licenseAgreed
}

class RayonStore: ObservableObject {
    private let crypto: AES = .shared

    private init() {
        licenseAgreed = UserDefaults
            .standard
            .value(forKey: UserDefaultKey.licenseAgreed.rawValue) as? Bool ?? false
        storeRecent = UDStoreRecent
        saveTemporarySession = UDSaveTemporarySession
        if let userIdentitiesEncrypted = UserDefaults
            .standard
            .value(forKey: UserDefaultKey.userIdentitiesEncrypted.rawValue) as? Data,
            let decrypted = crypto.decrypt(data: userIdentitiesEncrypted),
            let objects = try? documentDecoder.decode(RDIdentities.self, from: decrypted)
        {
            userIdentities = objects
        }
        if let remoteMachinesEncrypted = UserDefaults
            .standard
            .value(forKey: UserDefaultKey.remoteMachinesEncrypted.rawValue) as? Data,
            let decrypted = crypto.decrypt(data: remoteMachinesEncrypted),
            let objects = try? documentDecoder.decode(RDRemoteMachines.self, from: decrypted)
        {
            remoteMachines = objects
        }
        if let read = UserDefaults
            .standard
            .value(forKey: UserDefaultKey.remoteMachineRedactedLevel.rawValue) as? Int,
            let level = RDRemoteMachineRedactedLevel(rawValue: read)
        {
            remoteMachineRedactedLevel = level
        }
        if let userSnippetsEncrypted = UserDefaults
            .standard
            .value(forKey: UserDefaultKey.userSnippetsEncrypted.rawValue) as? Data,
            let decrypted = crypto.decrypt(data: userSnippetsEncrypted),
            let objects = try? documentDecoder.decode(RDSnippets.self, from: decrypted)
        {
            userSnippets = objects
        }
        if let recentRecordEncrypted = UserDefaults
            .standard
            .value(forKey: UserDefaultKey.recentRecordEncrypted.rawValue) as? Data,
            let decrypted = crypto.decrypt(data: recentRecordEncrypted),
            let objects = try? documentDecoder.decode([RecentConnection].self, from: decrypted)
        {
            recentRecord = objects
        }
    }

    public static let shared = RayonStore()

    let storeQueue = DispatchQueue(label: "wiki.qaq.rayon.store")

    @Published var licenseAgreed: Bool = false {
        didSet {
            storeQueue.async {
                UserDefaults.standard.set(self.licenseAgreed, forKey: UserDefaultKey.licenseAgreed.rawValue)
            }
        }
    }

    @Published var globalProgressInPresent: Bool = false
    var globalProgressCount: Int = 0 {
        didSet {
            if globalProgressCount == 0 {
                globalProgressInPresent = false
            } else {
                globalProgressInPresent = true
            }
        }
    }

    @Published var userIdentities: RDIdentities = .init() {
        didSet {
            storeQueue.async {
                guard let data = try? documentEncoder.encode(self.userIdentities),
                      let encrypt = self.crypto.encrypt(data: data)
                else {
                    assertionFailure()
                    return
                }
                UserDefaults
                    .standard
                    .set(encrypt, forKey: UserDefaultKey.userIdentitiesEncrypted.rawValue)
            }
        }
    }

    var userIdentitiesForAutoAuth: [RDIdentity] {
        userIdentities
            .identities
            .filter(\.authenticAutomatically)
            // make sure not to reopen too many times
            .sorted { $0.username < $1.username }
    }

    @Published var remoteMachineRedactedLevel: RDRemoteMachineRedactedLevel = .none {
        didSet {
            UserDefaults
                .standard
                .set(remoteMachineRedactedLevel.rawValue, forKey: UserDefaultKey.remoteMachineRedactedLevel.rawValue)
        }
    }

    @Published var remoteMachines: RDRemoteMachines = .init() {
        didSet {
            storeQueue.async {
                guard let data = try? documentEncoder.encode(self.remoteMachines),
                      let encrypt = self.crypto.encrypt(data: data)
                else {
                    assertionFailure()
                    return
                }
                UserDefaults
                    .standard
                    .set(encrypt, forKey: UserDefaultKey.remoteMachinesEncrypted.rawValue)
            }
        }
    }

    @UserDefaultsWrapper(key: "wiki.qaq.rayon.saveTemporarySession", defaultValue: true)
    private var UDSaveTemporarySession: Bool

    @Published var saveTemporarySession: Bool = false {
        didSet {
            UDSaveTemporarySession = saveTemporarySession
        }
    }

    @UserDefaultsWrapper(key: "wiki.qaq.rayon.storeRecent", defaultValue: true)
    private var UDStoreRecent: Bool

    @Published var storeRecent: Bool = false {
        didSet {
            UDStoreRecent = storeRecent
            if !storeRecent {
                recentRecord = []
            }
        }
    }

    enum RecentConnection: Codable, Equatable, Identifiable {
        var id: String {
            switch self {
            case let .command(command):
                return command.command
            case let .machine(machine):
                return machine.uuidString
            }
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }

        case command(command: SSHCommandReader)
        case machine(machine: RDRemoteMachine.ID)

        var equivalentSSHCommand: String {
            switch self {
            case let .command(command):
                return command.command
            case let .machine(machineID):
                let machine = RayonStore.shared.remoteMachines[machineID]
                guard let associatedIdentity = machine.associatedIdentity else {
                    return ""
                }
                guard let username = RayonStore.shared.userIdentities.identities.filter({ identity in
                    identity.id.uuidString == associatedIdentity
                }).first?.username else {
                    return ""
                }
                return "ssh \(username)@\(machine.remoteAddress) -p \(machine.remotePort)"
            }
        }
    }

    func cleanRecentIfNeeded() {
        let build = recentRecord
            .filter { record in
                switch record {
                case .command: return true
                case let .machine(machine): return remoteMachines[machine].isNotPlaceholder()
                }
            }
        mainActor {
            self.recentRecord = build
        }
    }

    @UserDefaultsWrapper(key: "wiki.qaq.rayon.maxRecentRecordCount", defaultValue: 8)
    var maxRecentRecordCount: Int

    @Published var recentRecord: [RecentConnection] = [] {
        didSet {
            storeQueue.async {
                guard let data = try? documentEncoder.encode(self.recentRecord),
                      let encrypt = self.crypto.encrypt(data: data)
                else {
                    assertionFailure()
                    return
                }
                UserDefaults
                    .standard
                    .set(encrypt, forKey: UserDefaultKey.recentRecordEncrypted.rawValue)
            }
        }
    }

    func storeRecentIfNeeded(from recent: RecentConnection) {
        guard storeRecent else {
            return
        }
        mainActor {
            for lookup in self.recentRecord where lookup == recent {
                return
            }
            self.recentRecord.insert(recent, at: 0)
            while self.recentRecord.count > self.maxRecentRecordCount {
                self.recentRecord.removeLast()
            }
        }
    }

    @discardableResult
    func registerServer(
        withAddress: String,
        withPort: String,
        withIdentity: RDIdentity.ID,
        session: NSRemoteShell
    ) -> RDRemoteMachine {
        let machine = RDRemoteMachine(
            remoteAddress: withAddress,
            remotePort: withPort,
            name: withAddress,
            group: "",
            lastConnection: Date(),
            lastBanner: session.remoteBanner ?? "",
            comment: session.resolvedRemoteIpAddress ?? "",
            associatedIdentity: withIdentity.uuidString,
            attachment: [:]
        )
        remoteMachines.machines.append(machine)
        return machine
    }

    @Published var userSnippets: RDSnippets = .init() {
        didSet {
            storeQueue.async {
                guard let data = try? documentEncoder.encode(self.userSnippets),
                      let encrypt = self.crypto.encrypt(data: data)
                else {
                    assertionFailure()
                    return
                }
                UserDefaults
                    .standard
                    .set(encrypt, forKey: UserDefaultKey.userSnippetsEncrypted.rawValue)
            }
        }
    }

    @Published var remoteSessions: [RDSession] = []

    private var _sessionPickup: UUID?
    var sessionPickup: UUID? {
        get {
            let read = _sessionPickup
            _sessionPickup = nil
            return read
        }
        set {
            _sessionPickup = newValue
        }
    }

    var remoteSessionWindows: [UUID: Window] = [:]
}

// MARK: Function

extension RayonStore {
    func findSimilarMachine(
        withAddr: String,
        withPort: String,
        withUsername: String?
    ) -> RDRemoteMachine.ID? {
        guard withAddr.count > 0, withPort.count > 0 else {
            return nil
        }
        for machine in remoteMachines.machines {
            if machine.remoteAddress == withAddr,
               machine.remotePort == withPort
            {
                if let withUsername = withUsername {
                    guard let sid = machine.associatedIdentity,
                          let rid = UUID(uuidString: sid)
                    else {
                        continue
                    }
                    let identity = userIdentities[rid]
                    if identity.username == withUsername {
                        return machine.id
                    } else {
                        continue
                    }
                } else {
                    return machine.id
                }
            }
        }
        return nil
    }

    func beginTemporarySessionStartup(
        for command: SSHCommandReader,
        requestIdentityFromBackgroundThread: @escaping () -> (RDIdentity.ID?),
        saveSessionOverrideControl: Bool = true,
        autoOpen: Bool = true
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
                UIBridge.presentError(with: "Unable to connect this machine, please check your network")
                return
            }

            var finalID: RDIdentity?

            var previousUsername: String?
            let search = self.userIdentitiesForAutoAuth
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
                    UIBridge.presentError(with: "Authentication is required for session startup")
                    return
                }
                let obtainRequest = self.userIdentities[request]
                guard obtainRequest.username.count > 0 else {
                    // this should be our error, check code instead
                    return
                }
                obtainRequest.callAuthenticationWith(remote: remote)

                finalID = obtainRequest
            }

            guard remote.isAuthenicated else {
                UIBridge.presentError(with: "Failed to authenticate this session")
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
                    self.remoteSessions.append(session)
                    if autoOpen { self.requestSessionInterface(session: session.id) }
                }
            } else {
                let machine = RDRemoteMachine(
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
                    self.remoteSessions.append(session)
                    if autoOpen { self.requestSessionInterface(session: session.id) }
                }
            }
        }
    }

    func beginSessionStartup(for machine: RDRemoteMachine.ID, autoOpen: Bool = true) {
        globalProgressCount += 1
        DispatchQueue.global().async {
            defer {
                // we no longer handle this flag later
                mainActor { self.globalProgressCount -= 1 }
            }
            debugPrint("begin session startup \(machine)")
            let machine = self.remoteMachines[machine]
            guard machine.remoteAddress.count > 0,
                  machine.remotePort.count > 0,
                  let intPort = Int(machine.remotePort)
            else {
                UIBridge.presentError(with: "unknown error: invalid session info")
                return
            }
            guard let rawIdentity = machine.associatedIdentity,
                  let compileIdentity = UUID(uuidString: rawIdentity)
            else {
                UIBridge.presentError(with: "unknown error: invalid session identity")
                return
            }
            let identity = self.userIdentities[compileIdentity]
            guard identity.username.count > 0 else {
                UIBridge.presentError(with: "unknown error: invalid session identity")
                return
            }
            let remote = NSRemoteShell()
                .setupConnectionHost(machine.remoteAddress)
                .setupConnectionPort(NSNumber(value: intPort))
                .setupConnectionTimeout(6)
                .requestConnectAndWait()
            guard remote.isConnected else {
                UIBridge.presentError(with: "Unable to connect this machine, please check your network")
                return
            }
            identity.callAuthenticationWith(remote: remote)
            guard remote.isAuthenicated else {
                UIBridge.presentError(with: "Unable to authenticate session, please check your identity setting")
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
                self.remoteSessions.append(session)
                if autoOpen { self.requestSessionInterface(session: session.id) }
            }
        }
    }

    func storeRecentIfNeeded(from machine: RDRemoteMachine.ID) {
        storeRecentIfNeeded(from: .machine(machine: machine))
    }

    func storeRecentIfNeeded(from command: SSHCommandReader) {
        storeRecentIfNeeded(from: .command(command: command))
    }

    func requestSessionInterface(session: RDSession.ID) {
        // lookup if any window is available before create new
        if let window = remoteSessionWindows[session] {
            window.makeKeyAndOrderFront(nil)
            return
        }
        for target in remoteSessions where target.id == session {
            let window = createNewWindowGroup(for: SessionView(session: target))
            storeSessionWindow(with: window, and: session)
            window.title = "Rayon Session"
            window.subtitle = "\(target.context.remoteIdentity.username)@\(target.context.remoteMachine.remoteAddress)"
            return
        }
        UIBridge.presentError(with: "Unable to request session interface, invalid or malformed session data was found")
    }

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

    func destorySession(with session: RDSession.ID) {
        if let window = remoteSessionWindows[session] {
            if let window = window as? NSCloseProtectedWindow {
                window.forceClose = true
            }
            window.close()
            remoteSessionWindows.removeValue(forKey: session)
        }
        for (index, lookup) in remoteSessions.enumerated() {
            if lookup.id == session {
                let context = lookup.context
                let shell = context.shell
                DispatchQueue.global().async {
                    debugPrint("[request disconnect] \(shell.remoteHost):\(shell.remotePort)")
                    shell.requestDisconnectAndWait()
                    debugPrint("[request disconnect] done at \(shell.remoteHost):\(shell.remotePort)")
                    context.nobodyCanSaveArc()
                }
                remoteSessions.remove(at: index)
                return
            }
        }
    }

    func createNewWindowGroup<T: View>(for view: T) -> Window {
        UIBridge.openNewWindow(from: view)
    }

    func beginBatchScriptExecution(for snippet: RDSnippet.ID, and machines: [RDRemoteMachine.ID]) {
        let snippet = userSnippets[snippet]
        guard snippet.code.count > 0 else {
            return
        }
        guard machines.count > 0 else {
            UIBridge.presentError(with: "No machine was selected for execution")
            return
        }
        let view = BatchSnippetExecView(snippet: snippet, machines: machines)
        UIBridge.openNewWindow(from: view)
    }
}
