//
//  File.swift
//
//
//  Created by Lakr Aream on 2022/3/1.
//

import Foundation

private var errorBlock: ((String) -> Void)?

public extension RayonStore {
    static func setPresentError(error: @escaping (String) -> Void) {
        errorBlock = error
    }

    static func presentError(_ str: String) {
        errorBlock?(str)
    }
}
