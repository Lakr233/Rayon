// Copyright (c) 2019-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Joseph Mattiello on 1/24/19.
//

public protocol DynamicNodeEncoding: Encodable {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding
}

extension Array: DynamicNodeEncoding where Element: DynamicNodeEncoding {
    public static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        Element.nodeEncoding(for: key)
    }
}

public extension DynamicNodeEncoding where Self: Collection, Self.Iterator.Element: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        Element.nodeEncoding(for: key)
    }
}
