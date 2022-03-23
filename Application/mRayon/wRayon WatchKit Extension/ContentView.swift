//
//  ContentView.swift
//  wRayon WatchKit Extension
//
//  Created by Lakr Aream on 2022/3/23.
//

import SwiftUI

import MachineStatus
import MachineStatusView
import NSRemoteShell
import RayonModule

struct ContentView: View {
    @StateObject var status = ServerStatus()

    @State var runAppear = true

    var body: some View {
        GeometryReader { r in
            ZStack {
                ScrollView {
                    VStack {
                        Spacer().frame(width: 100, height: 40)
                        ServerStatusViews
                            .createBaseStatusView(withContext: status)
                    }
                    .padding(1000)
                }
                .padding(-1000)
                .frame(
                    width: r.size.width * 1.25,
                    height: r.size.height * 1.25
                )
                .scaleEffect(0.8)
            }
            .frame(width: r.size.width, height: r.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            guard runAppear else { return }
            runAppear = false
            load()
        }
    }

    func load() {
        DispatchQueue.global().async {
            debugPrint("connect")
            let shell = NSRemoteShell()
                .setupConnectionTimeout(NSNumber(value: 10))
                .setupConnectionHost("")
                .setupConnectionPort(62022)
            shell.requestConnectAndWait()
            shell.authenticate(
                with: "root",
                andPassword: ""
            )
            guard shell.isAuthenticated else {
                debugPrint("failure")
                return
            }
            while true {
                status.requestInfoAndWait(with: shell)
                sleep(5)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
