//
//  RayonStore+Util.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/3/1.
//

import Foundation
import NSRemoteShell

private let documentEncoder = PropertyListEncoder()
private let documentDecoder = PropertyListDecoder()
private let crypto: AES = .shared
private let storeQueue = DispatchQueue(label: "wiki.qaq.rayon.store")

public extension RayonStore {
    enum UserDefaultKey: String {
        case identityGroupEncrypted
        case machineGroupEncrypted
        case snippetGroupEncrypted
        case recentRecordEncrypted
        case portForwardEncrypted
        case machineRedacted
        case licenseAgreed
        case openInterfaceAutomatically
    }

    func readEncryptedDefault<T: Codable>(from key: UserDefaultKey, _: T) -> T? {
        if let encryptedData = UserDefaults
            .standard
            .value(forKey: key.rawValue) as? Data,
            let decrypted = crypto.decrypt(data: encryptedData),
            let objects = try? documentDecoder.decode(T.self, from: decrypted)
        {
            return objects
        }
        return nil
    }

    func storeDefault(to key: UserDefaultKey, with data: Any) {
        UserDefaults
            .standard
            .set(data, forKey: key.rawValue)
    }

    func storeEncryptedDefault<T: Codable>(to key: UserDefaultKey, with data: T) {
        storeQueue.async {
            guard let data = try? documentEncoder.encode(data),
                  let encrypt = crypto.encrypt(data: data)
            else {
                return
            }
            UserDefaults
                .standard
                .set(encrypt, forKey: key.rawValue)
        }
    }

    func findSimilarMachine(
        withAddr: String,
        withPort: String,
        withUsername: String?
    ) -> RDMachine.ID? {
        guard withAddr.count > 0, withPort.count > 0 else {
            return nil
        }
        for machine in machineGroup.machines {
            if machine.remoteAddress == withAddr,
               machine.remotePort == withPort
            {
                if let withUsername = withUsername {
                    guard let sid = machine.associatedIdentity,
                          let rid = UUID(uuidString: sid)
                    else {
                        continue
                    }
                    let identity = identityGroup[rid]
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
}

public extension RayonStore {
    static func overrideImport(from data: Data, key: String) {
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data,
            format: nil
        ) else {
            print("unable to serialize property list")
            return
        }
        guard let dic = plist as? [String: Any] else {
            print("unexpected format")
            return
        }
        debugPrint(dic)
        guard let aes = AES(key: key, iv: key) else {
            print("failed to load crypto engine")
            return
        }

        func readEncrypted<T: Codable>(from data: Data, _: T) -> T? {
            if let decrypted = aes.decrypt(data: data),
               let objects = try? documentDecoder.decode(T.self, from: decrypted)
            {
                return objects
            }
            return nil
        }
        guard true,
              let identityGroupEncrypted = dic[UserDefaultKey.identityGroupEncrypted.rawValue] as? Data,
              let machineGroupEncrypted = dic[UserDefaultKey.machineGroupEncrypted.rawValue] as? Data,
              let snippetGroupEncrypted = dic[UserDefaultKey.snippetGroupEncrypted.rawValue] as? Data,
//            let recentRecordEncrypted = dic[UserDefaultKey.recentRecordEncrypted.rawValue] as? Data,
              let portForwardEncrypted = dic[UserDefaultKey.portForwardEncrypted.rawValue] as? Data,
//            let machineRedacted = dic[UserDefaultKey.machineRedacted.rawValue] as? Data,
//            let licenseAgreed = dic[UserDefaultKey.licenseAgreed.rawValue] as? Data,
//            let openInterfaceAutomatically = dic[UserDefaultKey.openInterfaceAutomatically.rawValue] as? Data
              let ig = readEncrypted(from: identityGroupEncrypted, RayonStore.shared.identityGroup.self),
              let mg = readEncrypted(from: machineGroupEncrypted, RayonStore.shared.machineGroup.self),
              let sg = readEncrypted(from: snippetGroupEncrypted, RayonStore.shared.snippetGroup.self),
              let pg = readEncrypted(from: portForwardEncrypted, RayonStore.shared.portForwardGroup.self),
              true
        else {
            print("broken payload")
            return
        }
        print("sending payload")

        func storeEncryptedDefault<T: Codable>(to key: UserDefaultKey, with data: T) {
            guard let data = try? documentEncoder.encode(data),
                  let encrypt = crypto.encrypt(data: data)
            else {
                return
            }
            UserDefaults
                .standard
                .set(encrypt, forKey: key.rawValue)
        }
        mainActor {
            RayonStore.shared.identityGroup = ig
            RayonStore.shared.machineGroup = mg
            RayonStore.shared.snippetGroup = sg
            RayonStore.shared.portForwardGroup = pg
            storeEncryptedDefault(to: .identityGroupEncrypted, with: ig)
            storeEncryptedDefault(to: .machineGroupEncrypted, with: mg)
            storeEncryptedDefault(to: .snippetGroupEncrypted, with: sg)
            storeEncryptedDefault(to: .portForwardEncrypted, with: pg)
        }
    }
}
