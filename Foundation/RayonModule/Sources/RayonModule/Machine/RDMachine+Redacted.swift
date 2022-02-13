//
//  RDMachine+Redacted.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/3/1.
//

import Foundation

public extension RDMachine {
    enum RedactedLevel: Int, Codable {
        case none = 0
        case sensitive = 1
        case all = 2
    }
}
