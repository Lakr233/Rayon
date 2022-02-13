//
//  Template.swift
//
//
//  Created by Lakr Aream on 2022/3/2.
//

import Combine
import Foundation
import NSRemoteShell
import XMLCoder

public extension ServerStatus {
    /// 服务器 GPU 信息
    struct GraphicsInfo: Codable, Equatable, Identifiable, DynamicNodeEncoding {
        public var id = UUID()

        public let version: String // CUDA version, like '11.2'
        public let units: [SingleGraphicsInfo]

        enum CodingKeys: String, CodingKey {
            case version = "cuda_version"
            case units = "gpu"
        }

        public static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
            switch key {
            case GraphicsInfo.CodingKeys.version: return .both
            default: return .element
            }
        }

        public init() {
            version = "unknown"
            units = []
        }

        public init?(withRemote shell: NSRemoteShell) {
            let downloadResult = downloadResultFrom(shell: shell, command: .obtainGraphicsInfo)
            guard let coder = (
                try? XMLDecoder().decode(
                    GraphicsInfo.self,
                    from: Data(downloadResult.utf8)
                )
            ) else {
                return nil
            }
            self = coder
        }
    }

    /// 单块 GPU 信息
    struct SingleGraphicsInfo: Codable, Equatable, Identifiable {
        public var id = UUID()

        public let uuid: String // GPU uuid from Nvidia
        public let name: String // GPU name, like '2080 Ti'
        public let memory: Memory
        public let vbios_version: String
        public let fan_speed: String
        public let utilization: Utilization

        static func s2f(_ status: String) -> Float {
            // 11019 MiB -> 11019
            let tmp = status.components(separatedBy: " ")[0]
            let num = Float(tmp) ?? 0
            return num
        }

        public struct Memory: Codable {
            public let total: Float
            public let used: Float
            public let free: Float

            public init(total: Float = 0, used: Float = 0, free: Float = 0) {
                self.total = total
                self.used = used
                self.free = free
            }

            public init(from decoder: Decoder) throws {
                // decode
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let t = try container.decode(String.self, forKey: .total)
                let u = try container.decode(String.self, forKey: .used)
                let f = try container.decode(String.self, forKey: .free)
                self.init(total: s2f(t), used: s2f(u), free: s2f(f))
            }
        }

        public struct Utilization: Codable {
            public let gpu_util: Float
            public let memory_util: Float
            public let encoder_util: Float
            public let decoder_util: Float

            public init(gpu_util: Float = 0, memory_util: Float = 0, encoder_util: Float = 0, decoder_util: Float = 0) {
                self.gpu_util = gpu_util
                self.memory_util = memory_util
                self.encoder_util = encoder_util
                self.decoder_util = decoder_util
            }

            public init(from decoder: Decoder) throws {
                // decode
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let g = try container.decode(String.self, forKey: .gpu_util)
                let m = try container.decode(String.self, forKey: .memory_util)
                let e = try container.decode(String.self, forKey: .encoder_util)
                let d = try container.decode(String.self, forKey: .decoder_util)
                self.init(gpu_util: s2f(g), memory_util: s2f(m), encoder_util: s2f(e), decoder_util: s2f(d))
            }
        }

        public enum CodingKeys: String, CodingKey {
            case uuid
            case name = "product_name"
            case memory = "fb_memory_usage"
            case vbios_version
            case fan_speed
            case utilization
        }

        public init(id: UUID = UUID(), uuid: String = "", name: String = "", memory: Memory = .init(), vbios_version: String = "", fan_speed: String = "", utilization: Utilization = .init()) {
            self.id = id
            self.uuid = uuid
            self.name = name
            self.memory = memory
            self.vbios_version = vbios_version
            self.fan_speed = fan_speed
            self.utilization = utilization
        }

        public static func == (lhs: SingleGraphicsInfo, rhs: SingleGraphicsInfo) -> Bool {
            lhs.id == rhs.id
        }

        public func description() -> String {
            """
            uuid: \(uuid) name: \(name)
            """
        }
    }
}
