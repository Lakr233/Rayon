//
//  LicenseView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/4.
//

import SwiftUI

struct LicenseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Divider().hidden()
                Text(loadLicense())
                    .textSelection(.enabled)
                    .font(.system(.caption, design: .monospaced))
            }
            .padding(.bottom)
            .padding(.horizontal)
        }
        .background(
            Color(UIColor.systemGray6)
                .ignoresSafeArea()
        )
        .navigationTitle("License")
    }

    func loadLicense() -> String {
        guard let bundle = Bundle.main.url(forResource: "LICENSE", withExtension: nil),
              let str = try? String(contentsOfFile: bundle.path)
        else {
            return "Failed to load license info."
        }
        return str
    }
}

struct LicenseView_Previews: PreviewProvider {
    static var previews: some View {
        LicenseView()
    }
}
