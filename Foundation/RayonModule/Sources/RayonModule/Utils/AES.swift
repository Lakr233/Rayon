//
//  AES.swift
//  PTFoundation
//
//  Created by Lakr Aream on 12/15/20.
//

import CommonCrypto
import Foundation
import Keychain

public struct AES {
    private let key: Data
    private let iv: Data

    public static let shared: AES = {
        #if DEBUG

            var keyBuilder = ""
            #if os(macOS)
                let platformExpert = IOServiceGetMatchingService(
                    kIOMasterPortDefault,
                    IOServiceMatching("IOPlatformExpertDevice")
                )
                guard platformExpert > 0 else {
                    fatalError()
                }
                guard let serialNumber = (
                    IORegistryEntryCreateCFProperty(
                        platformExpert,
                        kIOPlatformSerialNumberKey as CFString,
                        kCFAllocatorDefault,
                        0
                    )
                    .takeUnretainedValue() as? String
                )
                else {
                    fatalError()
                }
                IOObjectRelease(platformExpert)
                keyBuilder = serialNumber
            #else
                keyBuilder = "fdaisohfiuhfq34hifgraskhfiarhfgui34hibrfiuef"
            #endif

            let key = keyBuilder + keyBuilder + keyBuilder
            guard let aes = AES(key: key, iv: key) else {
                fatalError("Failed to initialize crypto engine for Rayon DEBUG")
            }
            return aes
        #else
            let keychainServiceID = "wiki.qaq.rayon.kcAccess"
            let masterKeyID = "wiki.qaq.rayon.MasterCrypto"
            let keychain = Keychain(service: keychainServiceID)
            var retry = 3
            var key: String?
            repeat {
                defer { retry -= 1 }
                do {
                    let master = try keychain.getString(masterKeyID)
                    if let master = master, master.count > 2 {
                        key = master
                        break
                    } else {
                        try keychain.remove(masterKeyID)
                        let new = UUID().uuidString
                        key = new
                        try keychain
                            .label("Rayon Master Crypto Key")
                            .comment("Rayon requires a master crypto key to access your encrypted data on disk andprotects your accounts")
                            .set(new, key: masterKeyID)
                        break
                    }
                } catch {
                    continue
                }
            } while retry > 0
            guard let key = key else {
                fatalError("Failed to load crypto keys for Rayon")
            }
            guard let aes = AES(key: key, iv: key) else {
                fatalError("Failed to initialize crypto engine for Rayon")
            }
            return aes
        #endif
    }()

    /// 初始化 AES 引擎
    /// - Parameters:
    ///   - initKey: 要求足够长 大于或等于 32
    ///   - initIV: 要求足够长 大于或等于 16
    internal init?(key initKey: String, iv initIV: String) {
        // 初始化密钥 核查长度要求
        if initKey.count < kCCKeySizeAES128 || initIV.count < kCCBlockSizeAES128 {
            return nil
        }
        // 修改 key 到指定长度
        var initKey = initKey
        while initKey.count < 32 { // 防止意外
            initKey += initKey
        }
        while initKey.count > 32 {
            initKey.removeLast()
        }
        guard initKey.count == kCCKeySizeAES128 || initKey.count == kCCKeySizeAES256,
              let keyData = initKey.data(using: .utf8)
        else {
            return nil
        }
        // 修改 iv 到指定长度
        var initIV = initIV
        while initIV.count < kCCBlockSizeAES128 { // 防止意外
            initIV += initIV
        }
        while initIV.count > kCCBlockSizeAES128 {
            initIV.removeLast()
        }
        guard initIV.count == kCCBlockSizeAES128, let ivData = initIV.data(using: .utf8) else {
            debugPrint("Error \(#file) \(#line): Failed to set an initial vector.")
            return nil
        }
        // 储存
        key = keyData
        iv = ivData
    }

    // MARK: - API

    public func encrypt(data: Data) -> Data? {
        crypt(data: data, option: CCOperation(kCCEncrypt))
    }

    public func decrypt(data: Data) -> Data? {
        crypt(data: data, option: CCOperation(kCCDecrypt))
    }

    // MARK: - INTERNAL

    private func crypt(data: Data?, option: CCOperation) -> Data? {
        guard let data = data else { return nil }

        let cryptLength = data.count + kCCBlockSizeAES128
        var cryptData = Data(count: cryptLength)

        let keyLength = key.count
        let options = CCOptions(kCCOptionPKCS7Padding)

        var bytesLength = Int(0)

        let status = cryptData.withUnsafeMutableBytes { cryptBytes in
            data.withUnsafeBytes { dataBytes in
                iv.withUnsafeBytes { ivBytes in
                    key.withUnsafeBytes { keyBytes in
                        CCCrypt(option, CCAlgorithm(kCCAlgorithmAES), options, keyBytes.baseAddress, keyLength, ivBytes.baseAddress, dataBytes.baseAddress, data.count, cryptBytes.baseAddress, cryptLength, &bytesLength)
                    }
                }
            }
        }

        guard UInt32(status) == UInt32(kCCSuccess) else {
            debugPrint("Error: Failed to crypt data. Status \(status)")
            return nil
        }

        cryptData.removeSubrange(bytesLength ..< cryptData.count)
        return cryptData
    }
}
