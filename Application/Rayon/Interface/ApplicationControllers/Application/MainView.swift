//
//  Interface.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/8.
//

import RayonModule
import SwiftUI

private var isBootstrapCompleted = false

struct MainView: View {
    @EnvironmentObject var store: RayonStore

    @State var openLicenseAgreementView: Bool = false

    var body: some View {
        NavigationView {
            SidebarView()
            WelcomeView().requiresFrame()
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
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    UIBridge.toggleSidebar()
                } label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.leading")
                }
            }
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
