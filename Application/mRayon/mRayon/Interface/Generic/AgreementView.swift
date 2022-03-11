//
//  AgreementView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/4.
//

import RayonModule
import SwiftUI
import SwiftUIPolyfill

struct AgreementView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
//        NavigationView {
        contentView
//        }
//        .navigationViewStyle(StackNavigationViewStyle())
    }

    struct AddButtonStyle: ViewModifier {
        func body(content: Content) -> some View {
            if #available(iOS 15.0, *) {
                content.buttonStyle(.borderedProminent)
            }
            else if #available(iOS 14.0, *)
            {
                content.buttonStyle(.automatic)
            }
        }
    }

    var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                Divider().hidden()
                CopyableText(loadLicense())
                    .font(.system(.caption, design: .monospaced))
                Divider().hidden()

                HStack {
                    Spacer()
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
                            .frame(width: 250)
                    }
                    .modifier(AddButtonStyle())
                    Spacer()
                }
            }
            .padding()
        }
        .background(
            Color(UIColor.systemGray6)
                .ignoresSafeArea()
        )
//        .navigationTitle("Agreement")
        .navigationBarTitleDisplayMode(.inline)
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
