// Copyright (c) 2019-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by James Bean on 7/18/19.
//

/// Container specialized for decoding XML choice elements.
struct XMLChoiceDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K

    // MARK: Properties

    /// A reference to the decoder we're reading from.
    private let decoder: XMLDecoderImplementation

    /// A reference to the container we're reading from.
    private let container: SharedBox<ChoiceBox>

    /// The path of coding keys taken to get to this point in decoding.
    public private(set) var codingPath: [CodingKey]

    // MARK: - Initialization

    /// Initializes `self` by referencing the given decoder and container.
    init(referencing decoder: XMLDecoderImplementation, wrapping container: SharedBox<ChoiceBox>) {
        self.decoder = decoder
        container.withShared { $0.key = decoder.keyTransform($0.key) }
        self.container = container
        codingPath = decoder.codingPath
    }

    // MARK: - KeyedDecodingContainerProtocol Methods

    public var allKeys: [Key] {
        container.withShared { [Key(stringValue: $0.key)!] }
    }

    public func contains(_ key: Key) -> Bool {
        container.withShared { $0.key == key.stringValue }
    }

    public func decodeNil(forKey _: Key) throws -> Bool {
        container.withShared { $0.element.isNull }
    }

    public func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        guard container.withShared({ $0.key == key.stringValue }), key is XMLChoiceCodingKey else {
            throw DecodingError.typeMismatch(
                at: codingPath,
                expectation: type,
                reality: container
            )
        }
        return try decoder.unbox(container.withShared { $0.element })
    }

    public func nestedContainer<NestedKey>(
        keyedBy _: NestedKey.Type, forKey _: Key
    ) throws -> KeyedDecodingContainer<NestedKey> {
        throw DecodingError.typeMismatch(
            at: codingPath,
            expectation: NestedKey.self,
            reality: container
        )
    }

    public func nestedUnkeyedContainer(forKey _: Key) throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            at: codingPath,
            expectation: Key.self,
            reality: container
        )
    }

    public func superDecoder() throws -> Decoder {
        throw DecodingError.typeMismatch(
            at: codingPath,
            expectation: Key.self,
            reality: container
        )
    }

    public func superDecoder(forKey _: Key) throws -> Decoder {
        throw DecodingError.typeMismatch(
            at: codingPath,
            expectation: Key.self,
            reality: container
        )
    }
}
