// Copyright (c) 2017-2020 Shawn Moore and XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Shawn Moore on 11/20/17.
//

import Foundation

extension XMLDecoderImplementation: SingleValueDecodingContainer {
    // MARK: SingleValueDecodingContainer Methods

    public func decodeNil() -> Bool {
        (try? topContainer().isNull) ?? true
    }

    public func decode(_: Bool.Type) throws -> Bool {
        try unbox(try topContainer())
    }

    public func decode(_: Decimal.Type) throws -> Decimal {
        try unbox(try topContainer())
    }

    public func decode<T: BinaryInteger & SignedInteger & Decodable>(_: T.Type) throws -> T {
        try unbox(try topContainer())
    }

    public func decode<T: BinaryInteger & UnsignedInteger & Decodable>(_: T.Type) throws -> T {
        try unbox(try topContainer())
    }

    public func decode(_: Float.Type) throws -> Float {
        try unbox(try topContainer())
    }

    public func decode(_: Double.Type) throws -> Double {
        try unbox(try topContainer())
    }

    public func decode(_: String.Type) throws -> String {
        try unbox(try topContainer())
    }

    public func decode(_: String.Type) throws -> Date {
        try unbox(try topContainer())
    }

    public func decode(_: String.Type) throws -> Data {
        try unbox(try topContainer())
    }

    public func decode<T: Decodable>(_: T.Type) throws -> T {
        try unbox(try topContainer())
    }
}
