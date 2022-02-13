//
//  XMLElementNode.swift
//  XMLCoder
//
//  Created by Benjamin Wetherfield on 6/4/20.
//

protocol XMLElementProtocol {}

@propertyWrapper public struct Element<Value>: XMLElementProtocol {
    public var wrappedValue: Value

    public init(_ wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}

extension Element: Codable where Value: Codable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }

    public init(from decoder: Decoder) throws {
        try wrappedValue = .init(from: decoder)
    }
}

extension Element: Equatable where Value: Equatable {}
extension Element: Hashable where Value: Hashable {}
