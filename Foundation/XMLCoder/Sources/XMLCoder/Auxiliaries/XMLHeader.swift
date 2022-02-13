// Copyright (c) 2018-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Vincent Esche on 12/18/18.
//

import Foundation

public struct XMLHeader {
    /// The XML standard that the produced document conforms to.
    public let version: Double?

    /// The encoding standard used to represent the characters in the produced document.
    public let encoding: String?

    /// Indicates whether a document relies on information from an external source.
    public let standalone: String?

    public init(version: Double? = nil, encoding: String? = nil, standalone: String? = nil) {
        self.version = version
        self.encoding = encoding
        self.standalone = standalone
    }

    func isEmpty() -> Bool {
        version == nil && encoding == nil && standalone == nil
    }

    func toXML() -> String? {
        guard !isEmpty() else {
            return nil
        }

        var string = "<?xml"

        if let version = version {
            string += " version=\"\(version)\""
        }

        if let encoding = encoding {
            string += " encoding=\"\(encoding)\""
        }

        if let standalone = standalone {
            string += " standalone=\"\(standalone)\""
        }

        string += "?>\n"

        return string
    }
}
