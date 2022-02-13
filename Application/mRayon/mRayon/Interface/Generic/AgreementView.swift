//
//  AgreementView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/4.
//

import RayonModule
import SwiftUI

struct AgreementView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            contentView
        }
//        .navigationViewStyle(StackNavigationViewStyle())
    }

    var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                Divider().hidden()
                Text(loadLicense())
                    .textSelection(.enabled)
                    .font(.system(.caption, design: .monospaced))
                Divider().hidden()
            }
            .padding()
        }
        .background(
            Color(UIColor.systemGray6)
                .ignoresSafeArea()
        )
//        .navigationTitle("Agreement")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                Button {
                    UIBridge.requiresConfirmation(
                        message: "I fully understand the license agreements and agree with it."
                    ) { yes in
                        if yes {
                            RayonStore.shared.licenseAgreed = true
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                } label: {
                    Text("Agree License")
                        .bold()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    func loadLicense() -> String {
        guard let bundle = Bundle.main.url(forResource: "EULA", withExtension: nil),
              let str = try? String(contentsOfFile: bundle.path)
        else {
            return "Failed to load license info."
        }
        return str
    }
}

struct AgreementView_Previews: PreviewProvider {
    static var previews: some View {
        AgreementView()
    }
}
