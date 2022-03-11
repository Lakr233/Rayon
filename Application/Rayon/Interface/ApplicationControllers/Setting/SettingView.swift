//
//  SettingView.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/3/10.
//

import RayonModule
import SwiftUI

struct SettingView: View {
    @EnvironmentObject var store: RayonStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Section {
                    Toggle("Reduced Effect", isOn: $store.reducedViewEffects)
                        .font(.system(.headline, design: .rounded))
                    Text("This option will remove animated blur background and star animation.")
                        .font(.system(.subheadline, design: .rounded))
                    Toggle("Disable Confirmation", isOn: $store.disableConformation)
                        .font(.system(.headline, design: .rounded))
                    Text("This option will remove the confirmation alert, use with caution.")
                        .font(.system(.subheadline, design: .rounded))
                    Toggle("Store Recent", isOn: $store.storeRecent)
                        .font(.system(.headline, design: .rounded))
                    Text("This option will save several most recent used machine.")
                        .font(.system(.subheadline, design: .rounded))
                } header: {
                    Text("Application")
                        .font(.system(.headline, design: .rounded))
                } footer: {
                    Divider()
                }
                Section {
                    Slider(value: Binding<Double>.init(get: {
                        Double(store.timeout)
                    }, set: { newValue in
                        store.timeout = Int(exactly: newValue) ?? 5
                    }), in: 2 ... 30, step: 1) { Group {} }
                    Text("SSH will report invalid connection after \(store.timeout) seconds.")
                        .font(.system(.subheadline, design: .rounded))
                    Slider(value: Binding<Double>.init(get: {
                        Double(store.monitorInterval)
                    }, set: { newValue in
                        store.monitorInterval = Int(exactly: newValue) ?? 5
                    }), in: 5 ... 60, step: 5) { Group {} }
                    Text("Server monitor will update information \(store.monitorInterval) seconds after last attempt.")
                        .font(.system(.subheadline, design: .rounded))
                } header: {
                    Text("Connection")
                        .font(.system(.headline, design: .rounded))
                } footer: {
                    Divider()
                }
                Label("EOF", systemImage: "text.append")
                    .font(.system(.caption2, design: .rounded))
            }
            .padding()
        }
        .navigationTitle("Setting")
    }
}
