//
//  SettingView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/2.
//

import RayonModule
import SwiftUI

struct SettingView: View {
    @StateObject var store = RayonStore.shared

    var body: some View {
        List {
            Section {
                Button {
                    UIBridge.open(url: URL(string: "https://github.com/Lakr233/Rayon")!)
                } label: {
                    Label("Get Source", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            } header: {
                Label("App", systemImage: "arrow.right")
            } footer: {
                Text("Rayon is open sourced at GitHub, any pull request are welcome!")
            }

            Section {
                Toggle("Store Recent", isOn: $store.storeRecent)
                Stepper(
                    "Timeout: \(store.timeout)",
                    value: $store.timeout,
                    in: 2 ... 30,
                    step: 1
                ) { _ in }
            } header: {
                Label("Connect", systemImage: "arrow.right")
            }

            Section {
                Toggle("Open at Connect", isOn: $store.openInterfaceAutomatically)
                Toggle("Reduced Effects", isOn: $store.reducedViewEffects)
            } header: {
                Label("Interface", systemImage: "arrow.right")
            }

            Section {
                NavigationLink {
                    LogView()
                } label: {
                    Text("Show App Log")
                }
            } header: {
                Label("Diagnostic", systemImage: "doc.text.below.ecg")
            }

            Section {
                NavigationLink {
                    LicenseView()
                } label: {
                    Text("Software License")
                }
            } header: {
                Label("License", systemImage: "arrow.right")
            }
        }
        .navigationTitle("Setting")
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        createPreview {
            AnyView(SettingView())
        }
    }
}
