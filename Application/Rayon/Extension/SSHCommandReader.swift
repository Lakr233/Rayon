//
//  SSHCommandReader.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import Foundation

struct SSHCommandReader: Codable, Equatable {
    let remoteAddress: String
    let remotePort: String
    let username: String

    var command: String {
        "ssh \(username)@\(remoteAddress) -p \(remotePort)"
    }

    init?(command: String) {
        var parser = command
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard parser.hasPrefix("ssh ") else {
            return nil
        }
        parser.removeFirst(4) // "ssh "
        guard let reader = parser
            .components(separatedBy: " ")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            reader.contains("@") // requires username, block anonymous login
        else {
            return nil
        }
        let component = reader.components(separatedBy: "@")
        guard component.count == 2 else {
            return nil
        }
        let name = component[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let addr = component[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count > 0, addr.count > 0 else {
            return nil
        }
        username = name
        remoteAddress = addr

        parser.removeFirst(reader.count)
        parser = parser.trimmingCharacters(in: .whitespacesAndNewlines)
        if parser.hasPrefix("-p") {
            parser.removeFirst(2)
            parser = parser.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let port = UInt16(parser) else {
                return nil
            }
            remotePort = "\(port)"
        } else {
            remotePort = "22"
        }
    }
}
