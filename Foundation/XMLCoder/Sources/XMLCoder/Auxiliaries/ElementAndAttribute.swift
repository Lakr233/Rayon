//
//  XMLBothNode.swift
//  XMLCoder
//
//  Created by Benjamin Wetherfield on 6/7/20.
//

public protocol XMLElementAndAttributeProtocol {}

@propertyWrapper public struct ElementAndAttribute<Value>: XMLElementAndAttributeProtocol {
    public var wrappedValue: Value

    public init(_ wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}

extension ElementAndAttribute: Codable where Value: Codable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }

    public init(from decoder: Decoder) throws {
        try wrappedValue = .init(from: decoder)
    }
}

extension ElementAndAttribute: Equatable where Value: Equatable {}
extension ElementAndAttribute: Hashable where Value: Hashable {}
