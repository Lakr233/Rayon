//
//  SessionPlaceholderView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/12.
//

import Colorful
import RayonModule
import SwiftUI

struct SessionPlaceholderView: View {
    @EnvironmentObject var context: RDSession.Context

    @StateObject
    var windowObserver: WindowObserver = .init()

    var body: some View {
        VStack(spacing: 10) {
            Image("Avatar")
                .antialiased(true)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)
        }
        .padding()
        .expended()
        .background(StarLinkView().ignoresSafeArea())
        .background(
            ColorfulView(
                colors: [Color.orange, Color.yellow],
                colorCount: 4
            )
            .ignoresSafeArea()
            .opacity(0.25)
        )
        .requiresFrame()
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
        windowObserver.window?.title = "Rayon Session"
        windowObserver.window?.subtitle = "\(context.identity.username)@\(context.machine.remoteAddress)"
    }

    func clearWindowTitle() {
        windowObserver.window?.title = ""
        windowObserver.window?.subtitle = ""
    }
}
