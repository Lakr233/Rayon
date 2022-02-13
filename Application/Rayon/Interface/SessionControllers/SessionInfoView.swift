//
//  SessionInfoView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/11.
//

import MachineStatus
import MachineStatusView
import RayonModule
import SwiftUI

struct SessionInfoView: View {
    @EnvironmentObject var context: RDSession.Context

    @StateObject
    var windowObserver: WindowObserver = .init()

    let timer = Timer
        .publish(every: 1, on: .main, in: .common)
        .autoconnect()
    let lock = NSLock()

    @StateObject var info = ServerStatus()
    @State var requestThrottle: Int = 5

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            ServerStatusViews
                .createBaseStatusView(withContext: info)
                .textSelection(.enabled)
                .padding(20)
        }
        .textSelection(.enabled)
        .animation(.interactiveSpring(), value: info)
        .onReceive(timer) { _ in
            timerReceiver()
        }
        .background(
            HostingWindowFinder { [weak windowObserver] window in
                windowObserver?.window = window
                setWindowTitle()
            }
        )
        .onAppear {
            setWindowTitle()
        }
        .onDisappear {
            clearWindowTitle()
        }
    }

    func setWindowTitle() {
        windowObserver.window?.title = "Machine Info"
        windowObserver.window?.subtitle = "\(context.identity.username)@\(context.machine.remoteAddress)"
    }

    func clearWindowTitle() {
        windowObserver.window?.title = ""
        windowObserver.window?.subtitle = ""
    }

    func timerReceiver() {
        guard lock.try() else {
            // operation in progress
            return
        }
        let sleepInterval = requestThrottle
        DispatchQueue.global().async {
            gathreingData(sleepInterval: sleepInterval)
            lock.unlock()
        }
    }

    func gathreingData(sleepInterval: Int) {
        debugPrint("gathreingData enter request")
        let begin = Date()
        info.requestInfoAndWait(with: context.shell)
        debugPrint("gathreingData leave request, used \(Date().timeIntervalSince(begin)) second")
        sleep(UInt32(exactly: sleepInterval) ?? 5)
    }
}
