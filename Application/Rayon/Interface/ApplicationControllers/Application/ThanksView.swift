//
//  ThanksView.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/13.
//

import Colorful
import SwiftUI

struct ThanksView: View {
    @Environment(\.presentationMode) var presentationMode

    @State var openLicenseInfo: Bool = false

    var body: some View {
        SheetTemplate.makeSheet(
            title: "Acknowledgment",
            body: AnyView(sheetBody)
        ) { _ in
            presentationMode.wrappedValue.dismiss()
        }
        .sheet(isPresented: $openLicenseInfo, onDismiss: nil) {
            LicenseView()
        }
    }

    var sheetBody: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image("Avatar")
                    .antialiased(true)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                Divider()
                Text("Made with love by [@Lakr233](https://twitter.com/Lakr233)")
                Text("along with his friends: [@__oquery](https://twitter.com/__oquery) [@zlind0](https://github.com/zlind0) [@unixzii](https://twitter.com/unixzii) [@82flex](https://twitter.com/82flex) [@xnth97](https://twitter.com/xnth97)")
                Text("Source code available at: [GitHub](https://github.com/Lakr233/Rayon)")
                Button {
                    openLicenseInfo = true
                } label: {
                    Label("License Info", systemImage: "flag.2.crossed.fill")
                }
            }
            .font(.system(.body, design: .rounded))
            .padding()
        }
        .frame(width: 600, height: 250)
        .background(
            ColorfulView(
                colors: [Color.accentColor],
                colorCount: 4
            )
            .ignoresSafeArea()
            .opacity(0.25)
        )
    }
}
