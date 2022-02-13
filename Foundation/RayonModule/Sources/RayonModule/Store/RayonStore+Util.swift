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
        case machineRedacted
        case licenseAgreed
        case timeout
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
