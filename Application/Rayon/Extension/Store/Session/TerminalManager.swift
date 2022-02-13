//
//  TerminalManager.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/3/1.
//

import Foundation
import NSRemoteShell
import XTerminalUI

public class TerminalManager {
    public static let shared = TerminalManager()
    private init() {}

    public class Core: Identifiable {
        public let id: UUID

        public init(id: UUID) {
            self.id = id
        }

        public let coreUI = STerminalView()
        public let lock = NSLock()
        public var setupComplete: Bool = false
        public var completed: Bool = false
        public var title: String = ""
        public var withTermianlSize: (() -> CGSize)?
        public var withWriteData: (() -> String)?
        public var withOutput: ((String) -> Void)?
        public var withContinuationHandler: (() -> Bool)?
        public var stop: Bool = false

        public func startIfNeeded(with shell: NSRemoteShell) {
            lock.lock()
            defer { lock.unlock() }
            guard !setupComplete else { return }
            setupComplete = true
            debugPrint("processing channel startup")
            DispatchQueue.global().async { self.processStartup(with: shell) }
        }

        private func processStartup(with shell: NSRemoteShell) {
            let canOpen = withContinuationHandler?() ?? false
            guard canOpen else {
                debugPrint("refusing channel startup due to broken data flow")
                return
            }
            shell.open(withTerminal: "xterm") { [weak self] in
                self?.withTermianlSize?() ?? CGSize(width: 50, height: 20)
            } withWriteData: { [weak self] in
                self?.withWriteData?() ?? ""
            } withOutput: { [weak self] output in
                self?.withOutput?(output)
            } withContinuationHandler: { [weak self] in
                // closed
                if self?.stop ?? true { return false }
                // ask the view for state
                return self?.withContinuationHandler?() ?? false
            }
            coreUI.write("\r\n[*] Channel Connection Closed\r\n")
            completed = true
            coreUI
                .setupBufferChain(callback: nil)
                .setupTitleChain(callback: nil)
                .setupBellChain(callback: nil)
            withTermianlSize = nil
            withWriteData = nil
            withOutput = nil
            withContinuationHandler = nil
        }

        public func rebindChain(
            termianlSize: (() -> CGSize)?,
            writeData: (() -> String)?,
            output: ((String) -> Void)?,
            continuationHandler: (() -> Bool)?
        ) {
            withTermianlSize = termianlSize
            withWriteData = writeData
            withOutput = output
            withContinuationHandler = continuationHandler
        }

//        let data: String // ? not required ? since we hold ref to coreUI
    }

    private var storage: [Core] = []

    public func loadTerminal(for session: UUID) -> Core {
        for lookup in storage where lookup.id == session {
            return lookup
        }
        let create = Core(id: session)
        storage.append(create)
        return create
    }

    // no need to destroy the terminal session(aka libssh2 channel)
    // when the session(aka libssh2 session) destroy
    // connection will close then release any object
}
