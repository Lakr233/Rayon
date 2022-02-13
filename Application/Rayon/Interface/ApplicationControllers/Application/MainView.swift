//
//  Interface.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/8.
//

import SwiftUI

private var isBootstrapCompleted = false

struct MainView: View {
    @EnvironmentObject var store: RayonStore

    @StateObject
    var windowObserver: WindowObserver = .init()

    @State var openLicenseAgreementView: Bool = false

    var body: some View {
        NavigationView {
            SidebarView()
            WelcomeView()
        }
        .onAppear {
            openLicenseIfNeeded()
        }
        .sheet(isPresented: $openLicenseAgreementView) {
            openLicenseIfNeeded()
        } content: {
            AgreementView()
        }
        .overlay(
            Color.black
                .opacity(store.globalProgressInPresent ? 0.5 : 0)
                .overlay(
                    SheetTemplate.makeProgress(text: "Operation in progress")
                        .padding()
                        .background(Color("Background"))
                        .roundedCorner()
                        .dropShadow()
                        .opacity(store.globalProgressInPresent ? 1 : 0)
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: store.globalProgressInPresent)
        )
        .background(
            HostingWindowFinder { [weak windowObserver] window in
                windowObserver?.window = window
                guard let window = window else {
                    return
                }
                guard !isBootstrapCompleted else {
                    return
                }
                isBootstrapCompleted = true

                window.tabbingMode = .disallowed
                let windows = NSApplication
                    .shared
                    .windows
                var notKeyWindow = windows
                    .filter { !$0.isKeyWindow }
                if notKeyWindow.count > 0,
                   notKeyWindow.count == windows.count
                {
                    // don't close them all
                    notKeyWindow.removeFirst()
                }
                notKeyWindow.forEach { $0.close() }
                window.tabbingMode = .automatic
            }
        )
        .toolbar {
            #if os(macOS)
                ToolbarItem(placement: .navigation) {
                    Button {
                        UIBridge.toggleSidebar()
                    } label: {
                        Label("Toggle Sidebar", systemImage: "sidebar.leading")
                    }
                }
            #endif
        }
    }

    func openLicenseIfNeeded() {
        mainActor(delay: 0.5) {
            guard store.licenseAgreed else {
                openLicenseAgreementView = true
                return
            }
        }
    }
}
