// Copyright (c) 2017-2021 Shawn Moore and XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Shawn Moore on 11/21/17.
//

import Foundation

// MARK: Decoding Containers

struct XMLKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K
    typealias KeyedContainer = SharedBox<KeyedBox>
    typealias UnkeyedContainer = SharedBox<UnkeyedBox>

    // MARK: Properties

    /// A reference to the decoder we're reading from.
    private let decoder: XMLDecoderImplementation

    /// A reference to the container we're reading from.
    private let container: KeyedContainer

    /// The path of coding keys taken to get to this point in decoding.
    public private(set) var codingPath: [CodingKey]

    // MARK: - Initialization

    /// Initializes `self` by referencing the given decoder and container.
    init(
        referencing decoder: XMLDecoderImplementation,
        wrapping container: KeyedContainer
    ) {
        self.decoder = decoder
        container.withShared {
            $0.elements = .init($0.elements.map { (decoder.keyTransform($0), $1) })
            $0.attributes = .init($0.attributes.map { (decoder.keyTransform($0), $1) })
        }
        self.container = container
        codingPath = decoder.codingPath
    }

    // MARK: - KeyedDecodingContainerProtocol Methods

    public var allKeys: [Key] {
        let elementKeys = container.withShared { keyedBox in
            keyedBox.elements.keys.compactMap { Key(stringValue: $0) }
        }

        let attributeKeys = container.withShared { keyedBox in
            keyedBox.attributes.keys.compactMap { Key(stringValue: $0) }
        }

        return attributeKeys + elementKeys
    }

    public func contains(_ key: Key) -> Bool {
        let elements = container.withShared { keyedBox in
            keyedBox.elements[key.stringValue]
        }

        let attributes = container.withShared { keyedBox in
            keyedBox.attributes[key.stringValue]
        }

        return !elements.isEmpty || !attributes.isEmpty
    }

    public func decodeNil(forKey key: Key) throws -> Bool {
        let elements = container.withShared { keyedBox in
            keyedBox.elements[key.stringValue]
        }

        let attributes = container.withShared { keyedBox in
            keyedBox.attributes[key.stringValue]
        }

        let box = elements.first ?? attributes.first

        if box is SingleKeyedBox {
            return false
        }

        return box?.isNull ?? true
    }

    public func decode<T: Decodable>(
        _ type: T.Type, forKey key: Key
    ) throws -> T {
        let attributeFound = container.withShared { keyedBox in
            !keyedBox.attributes[key.stringValue].isEmpty
        }

        let elementFound = container.withShared { keyedBox in
            !keyedBox.elements[key.stringValue].isEmpty || keyedBox.value != nil
        }

        if let type = type as? AnySequence.Type,
           !attributeFound,
           !elementFound,
           let result = type.init() as? T
        {
            return result
        }

        return try decodeConcrete(type, forKey: key)
    }

    public func nestedContainer<NestedKey>(
        keyedBy _: NestedKey.Type, forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> {
        decoder.codingPath.append(key)
        defer { decoder.codingPath.removeLast() }

        let elements = container.withShared { keyedBox in
            keyedBox.elements[key.stringValue]
        }

        let attributes = container.withShared { keyedBox in
            keyedBox.attributes[key.stringValue]
        }

        guard let value = elements.first ?? attributes.first else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(
                codingPath: codingPath,
                debugDescription:
                """
                Cannot get \(KeyedDecodingContainer<NestedKey>.self) -- \
                no value found for key \"\(key.stringValue)\"
                """
            ))
        }

        let container: XMLKeyedDecodingContainer<NestedKey>
        if let keyedContainer = value as? KeyedContainer {
            container = XMLKeyedDecodingContainer<NestedKey>(
                referencing: decoder,
                wrapping: keyedContainer
            )
        } else if let keyedContainer = value as? KeyedBox {
            container = XMLKeyedDecodingContainer<NestedKey>(
                referencing: decoder,
                wrapping: SharedBox(keyedContainer)
            )
        } else {
            throw DecodingError.typeMismatch(
                at: codingPath,
                expectation: [String: Any].self,
                reality: value
            )
        }

        return KeyedDecodingContainer(container)
    }

    public func nestedUnkeyedContainer(
        forKey key: Key
    ) throws -> UnkeyedDecodingContainer {
        decoder.codingPath.append(key)
        defer { decoder.codingPath.removeLast() }

        let elements = container.unboxed.elements[key.stringValue]

        if let containsKeyed = elements as? [KeyedBox], containsKeyed.count == 1, let keyed = containsKeyed.first {
            return XMLUnkeyedDecodingContainer(
                referencing: decoder,
                wrapping: SharedBox(keyed.elements.map(SingleKeyedBox.init))
            )
        } else {
            return XMLUnkeyedDecodingContainer(
                referencing: decoder,
                wrapping: SharedBox(elements)
            )
        }
    }

    public func superDecoder() throws -> Decoder {
        try _superDecoder(forKey: XMLKey.super)
    }

    public func superDecoder(forKey key: Key) throws -> Decoder {
        try _superDecoder(forKey: key)
    }
}

/// Private functions
extension XMLKeyedDecodingContainer {
    private func _errorDescription(of key: CodingKey) -> String {
        switch decoder.options.keyDecodingStrategy {
        case .convertFromSnakeCase:
            // In this case we can attempt to recover the original value by
            // reversing the transform
            let original = key.stringValue
            let converted = XMLEncoder.KeyEncodingStrategy
                ._convertToSnakeCase(original)
            if converted == original {
                return "\(key) (\"\(original)\")"
            } else {
                return "\(key) (\"\(original)\"), converted to \(converted)"
            }
        default:
            // Otherwise, just report the converted string
            return "\(key) (\"\(key.stringValue)\")"
        }
    }

    private func decodeSignedInteger<T>(_ type: T.Type,
                                        forKey key: Key) throws -> T
        where T: BinaryInteger & SignedInteger & Decodable
    {
        try decodeConcrete(type, forKey: key)
    }

    private func decodeUnsignedInteger<T>(_ type: T.Type,
                                          forKey key: Key) throws -> T
        where T: BinaryInteger & UnsignedInteger & Decodable
    {
        try decodeConcrete(type, forKey: key)
    }

    private func decodeFloatingPoint<T>(_ type: T.Type,
                                        forKey key: Key) throws -> T
        where T: BinaryFloatingPoint & Decodable
    {
        try decodeConcrete(type, forKey: key)
    }

    private func decodeConcrete<T: Decodable>(
        _ type: T.Type,
        forKey key: Key
    ) throws -> T {
        guard let strategy = decoder.nodeDecodings.last else {
            preconditionFailure(
                """
                Attempt to access node decoding strategy from empty stack.
                """
            )
        }

        let elements = container
            .withShared { keyedBox -> [KeyedBox.Element] in
                keyedBox.elements[key.stringValue].map {
                    if let singleKeyed = $0 as? SingleKeyedBox {
                        return singleKeyed.element.isNull ? singleKeyed : singleKeyed.element
                    } else {
                        return $0
                    }
                }
            }

        let attributes = container.withShared { keyedBox in
            keyedBox.attributes[key.stringValue]
        }

        decoder.codingPath.append(key)
        let nodeDecodings = decoder.options.nodeDecodingStrategy.nodeDecodings(
            forType: T.self,
            with: decoder
        )
        decoder.nodeDecodings.append(nodeDecodings)
        defer {
            _ = decoder.nodeDecodings.removeLast()
            decoder.codingPath.removeLast()
        }
        let box: Box

        // You can't decode sequences from attributes, but other strategies
        // need special handling for empty sequences.
        if strategy(key) != .attribute, elements.isEmpty,
           let empty = (type as? AnySequence.Type)?.init() as? T
        {
            return empty
        }

        // If we are looking at a coding key value intrinsic where the expected type is `String` and
        // the value is empty, return `""`.
        if strategy(key) != .attribute, elements.isEmpty, attributes.isEmpty, type == String.self, key.stringValue == "", let emptyString = "" as? T {
            return emptyString
        }

        switch strategy(key) {
        case .attribute?:
            box = try getAttributeBox(attributes, key)
        case .element?:
            box = elements
        case .elementOrAttribute?:
            box = try getAttributeOrElementBox(attributes, elements, key)
        default:
            switch type {
            case is XMLAttributeProtocol.Type:
                box = try getAttributeBox(attributes, key)
            case is XMLElementProtocol.Type:
                box = elements
            default:
                box = try getAttributeOrElementBox(attributes, elements, key)
            }
        }

        let value: T?
        if !(type is AnySequence.Type), let unkeyedBox = box as? UnkeyedBox,
           let first = unkeyedBox.first
        {
            // Handle case where we have held onto a `SingleKeyedBox`
            if let singleKeyed = first as? SingleKeyedBox {
                if singleKeyed.element.isNull {
                    value = try decoder.unbox(singleKeyed)
                } else {
                    value = try decoder.unbox(singleKeyed.element)
                }
            } else {
                value = try decoder.unbox(first)
            }
        } else if box.isNull, let type = type as? XMLOptionalAttributeProtocol.Type, let nullAttribute = type.init() as? T {
            value = nullAttribute
        } else {
            value = try decoder.unbox(box)
        }

        if value == nil, let type = type as? AnyOptional.Type,
           let result = type.init() as? T
        {
            return result
        }

        guard let unwrapped = value else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription:
                "Expected \(type) value but found null instead."
            ))
        }
        return unwrapped
    }

    private func getAttributeBox(_ attributes: [KeyedBox.Attribute], _: Key) throws -> Box {
        let attributeBox = attributes.first ?? NullBox()
        return attributeBox
    }

    private func getAttributeOrElementBox(_ attributes: [KeyedBox.Attribute], _ elements: [KeyedBox.Element], _ key: Key) throws -> Box {
        guard
            let anyBox = elements.isEmpty ? attributes.first : elements as Box?
        else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription:
                """
                No attribute or element found for key \
                \(_errorDescription(of: key)).
                """
            ))
        }
        return anyBox
    }

    private func _superDecoder(forKey key: CodingKey) throws -> Decoder {
        decoder.codingPath.append(key)
        defer { decoder.codingPath.removeLast() }

        let elements = container.withShared { keyedBox in
            keyedBox.elements[key.stringValue]
        }

        let attributes = container.withShared { keyedBox in
            keyedBox.attributes[key.stringValue]
        }

        let box: Box = elements.first ?? attributes.first ?? NullBox()
        return XMLDecoderImplementation(
            referencing: box,
            options: decoder.options,
            nodeDecodings: decoder.nodeDecodings,
            codingPath: decoder.codingPath
        )
    }
}
